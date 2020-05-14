# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#
# See the COPYING file for license information.
#
# Copyright (c) 2007 Guillaume Chazarain <guichaz@gmail.com>

# Allow printing with same syntax in Python 2/3
from __future__ import print_function

import curses
import errno
import locale
import math
import optparse
import os
import select
import signal
import sys
import time

from iotop.data import find_uids, TaskStatsNetlink, ProcessList, Stats
from iotop.data import ThreadInfo
from iotop.version import VERSION
from iotop import ioprio
from iotop.ioprio import IoprioSetError

#
# Utility functions for the UI
#

UNITS = ['B', 'K', 'M', 'G', 'T', 'P', 'E']

def human_size(size):
    if size > 0:
        sign = ''
    elif size < 0:
        sign = '-'
        size = -size
    else:
        return '0.00 B'

    expo = int(math.log(size / 2, 2) / 10)
    return '%s%.2f %s' % (sign, (float(size) / (1 << (10 * expo))), UNITS[expo])

def format_size(options, bytes):
    if options.kilobytes:
        return '%.2f K' % (bytes / 1024.0)
    return human_size(bytes)

def format_bandwidth(options, size, duration):
    return format_size(options, size and float(size) / duration) + '/s'

def format_stats(options, process, duration):
    # Keep in sync with TaskStatsNetlink.members_offsets and
    # IOTopUI.get_data(self)
    def delay2percent(delay): # delay in ns, duration in s
        return '%.2f %%' % min(99.99, delay / (duration * 10000000.0))
    if options.accumulated:
        stats = process.stats_accum
        display_format = lambda size, duration: format_size(options, size)
        duration = time.time() - process.stats_accum_timestamp
    else:
        stats = process.stats_delta
        display_format = lambda size, duration: format_bandwidth(
                                                        options, size, duration)
    io_delay = delay2percent(stats.blkio_delay_total)
    swapin_delay = delay2percent(stats.swapin_delay_total)
    read_bytes = display_format(stats.read_bytes, duration)
    written_bytes = stats.write_bytes - stats.cancelled_write_bytes
    written_bytes = max(0, written_bytes)
    write_bytes = display_format(written_bytes, duration)
    return io_delay, swapin_delay, read_bytes, write_bytes

def get_max_pid_width():
    try:
        return len(open('/proc/sys/kernel/pid_max').read().strip())
    except Exception as e:
        print(e)
        # Reasonable default in case something fails
        return 5

MAX_PID_WIDTH = get_max_pid_width()

#
# UI Exceptions
#

class CancelInput(Exception): pass
class InvalidInt(Exception): pass
class InvalidPid(Exception): pass
class InvalidTid(Exception): pass
class InvalidIoprioData(Exception): pass

#
# The UI
#

class IOTopUI(object):
    # key, reverse
    sorting_keys = [
        (lambda p, s: p.pid, False),
        (lambda p, s: p.ioprio_sort_key(), False),
        (lambda p, s: p.get_user(), False),
        (lambda p, s: s.read_bytes, True),
        (lambda p, s: s.write_bytes - s.cancelled_write_bytes, True),
        (lambda p, s: s.swapin_delay_total, True),
        # The default sorting (by I/O % time) should show processes doing
        # only writes, without waiting on them
        (lambda p, s: s.blkio_delay_total or
                      int(not(not(s.read_bytes or s.write_bytes))), True),
        (lambda p, s: p.get_cmdline(), False),
    ]

    def __init__(self, win, process_list, options):
        self.process_list = process_list
        self.options = options
        self.sorting_key = 6
        self.sorting_reverse = IOTopUI.sorting_keys[self.sorting_key][1]
        if not self.options.batch:
            self.win = win
            self.resize()
            try:
                curses.use_default_colors()
                curses.start_color()
                curses.curs_set(0)
            except curses.error:
                # This call can fail with misconfigured terminals, for example
                # TERM=xterm-color. This is harmless
                pass

    def resize(self):
        self.height, self.width = self.win.getmaxyx()

    def run(self):
        iterations = 0
        poll = select.poll()
        if not self.options.batch:
            poll.register(sys.stdin.fileno(), select.POLLIN|select.POLLPRI)
        while self.options.iterations is None or \
              iterations < self.options.iterations:
            total, actual = self.process_list.refresh_processes()
            self.refresh_display(iterations == 0, total, actual,
                                 self.process_list.duration)
            if self.options.iterations is not None:
                iterations += 1
                if iterations >= self.options.iterations:
                    break
            elif iterations == 0:
                iterations = 1

            try:
                events = poll.poll(self.options.delay_seconds * 1000.0)
            except select.error as e:
                if e.args and e.args[0] == errno.EINTR:
                    events = []
                else:
                    raise
            for (fd, event) in events:
                if event & (select.POLLERR | select.POLLHUP):
                    sys.exit(1)
            if not self.options.batch:
                self.resize()
            if events:
                key = self.win.getch()
                self.handle_key(key)

    def reverse_sorting(self):
        self.sorting_reverse = not self.sorting_reverse

    def adjust_sorting_key(self, delta):
        orig_sorting_key = self.sorting_key
        self.sorting_key += delta
        self.sorting_key = max(0, self.sorting_key)
        self.sorting_key = min(len(IOTopUI.sorting_keys) - 1, self.sorting_key)
        if orig_sorting_key != self.sorting_key:
            self.sorting_reverse = IOTopUI.sorting_keys[self.sorting_key][1]

    # I wonder if switching to urwid for the display would be better here

    def prompt_str(self, prompt, default=None, empty_is_cancel=True):
        self.win.hline(1, 0, ord(' ') | curses.A_NORMAL, self.width)
        self.win.addstr(1, 0, prompt, curses.A_BOLD)
        self.win.refresh()
        curses.echo()
        curses.curs_set(1)
        inp = self.win.getstr(1, len(prompt))
        curses.curs_set(0)
        curses.noecho()
        if inp not in (None, ''):
            return inp
        if empty_is_cancel:
            raise CancelInput()
        return default

    def prompt_int(self, prompt, default = None, empty_is_cancel = True):
        inp = self.prompt_str(prompt, default, empty_is_cancel)
        try:
            return int(inp)
        except ValueError:
            raise InvalidInt()

    def prompt_pid(self):
        try:
            return self.prompt_int('PID to ionice: ')
        except InvalidInt:
            raise InvalidPid()
        except CancelInput:
            raise

    def prompt_tid(self):
        try:
            return self.prompt_int('TID to ionice: ')
        except InvalidInt:
            raise InvalidTid()
        except CancelInput:
            raise

    def prompt_data(self, ioprio_data):
        try:
            if ioprio_data is not None:
                inp = self.prompt_int('I/O priority data (0-7, currently %s): '
                                      % ioprio_data, ioprio_data, False)
            else:
                inp = self.prompt_int('I/O priority data (0-7): ', None, False)
        except InvalidInt:
            raise InvalidIoprioData()
        if inp < 0 or inp > 7:
            raise InvalidIoprioData()
        return inp

    def prompt_set(self, prompt, display_list, ret_list, selected):
        try:
            selected = ret_list.index(selected)
        except ValueError:
            selected = -1
        set_len = len(display_list) - 1
        while True:
            self.win.hline(1, 0, ord(' ') | curses.A_NORMAL, self.width)
            self.win.insstr(1, 0, prompt, curses.A_BOLD)
            offset = len(prompt)
            for i, item in enumerate(display_list):
                display = ' %s ' % item
                if i is selected:
                    attr = curses.A_REVERSE
                else:
                    attr = curses.A_NORMAL
                self.win.insstr(1, offset, display, attr)
                offset += len(display)
            while True:
                key = self.win.getch()
                if key in (curses.KEY_LEFT, ord('l')) and selected > 0:
                    selected -= 1
                    break
                elif key in (curses.KEY_RIGHT, ord('r')) and selected < set_len:
                    selected += 1
                    break
                elif key in (curses.KEY_ENTER, ord('\n'), ord('\r')):
                    return ret_list[selected]
                elif key in (27, curses.KEY_CANCEL, curses.KEY_CLOSE,
                             curses.KEY_EXIT, ord('q'), ord('Q')):
                    raise CancelInput()

    def prompt_class(self, ioprio_class=None):
        prompt = 'I/O priority class: '
        classes_prompt = ['Real-time', 'Best-effort', 'Idle']
        classes_ret = ['rt', 'be', 'idle']
        if ioprio_class is None:
            ioprio_class = 2
        inp = self.prompt_set(prompt, classes_prompt, classes_ret, ioprio_class)
        return inp

    def prompt_error(self, error = 'Error!'):
        self.win.hline(1, 0, ord(' ') | curses.A_NORMAL, self.width)
        self.win.insstr(1, 0, '  %s  ' % error, curses.A_REVERSE)
        self.win.refresh()
        time.sleep(1)

    def prompt_clear(self):
        self.win.hline(1, 0, ord(' ') | curses.A_NORMAL, self.width)
        self.win.refresh()

    def handle_key(self, key):
        def toggle_accumulated():
            self.options.accumulated ^= True
        def toggle_only_io():
            self.options.only ^= True
        def toggle_processes():
            self.options.processes ^= True
            self.process_list.clear()
            self.process_list.refresh_processes()
        def ionice():
            try:
                if self.options.processes:
                    pid = self.prompt_pid()
                    exec_unit = self.process_list.get_process(pid)
                else:
                    tid = self.prompt_tid()
                    exec_unit = ThreadInfo(tid,
                                         self.process_list.taskstats_connection)
                ioprio_value = exec_unit.get_ioprio()
                (ioprio_class, ioprio_data) = \
                                          ioprio.to_class_and_data(ioprio_value)
                ioprio_class = self.prompt_class(ioprio_class)
                if ioprio_class == 'idle':
                    ioprio_data = 0
                else:
                    ioprio_data = self.prompt_data(ioprio_data)
                exec_unit.set_ioprio(ioprio_class, ioprio_data)
                self.process_list.clear()
                self.process_list.refresh_processes()
            except IoprioSetError as e:
                self.prompt_error('Error setting I/O priority: %s' % e.err)
            except InvalidPid:
                self.prompt_error('Invalid process id!')
            except InvalidTid:
                self.prompt_error('Invalid thread id!')
            except InvalidIoprioData:
                self.prompt_error('Invalid I/O priority data!')
            except InvalidInt:
                self.prompt_error('Invalid integer!')
            except CancelInput:
                self.prompt_clear()
            else:
                self.prompt_clear()

        key_bindings = {
            ord('q'):
                lambda: sys.exit(0),
            ord('Q'):
                lambda: sys.exit(0),
            ord('r'):
                lambda: self.reverse_sorting(),
            ord('R'):
                lambda: self.reverse_sorting(),
            ord('a'):
                toggle_accumulated,
            ord('A'):
                toggle_accumulated,
            ord('o'):
                toggle_only_io,
            ord('O'):
                toggle_only_io,
            ord('p'):
                toggle_processes,
            ord('P'):
                toggle_processes,
            ord('i'):
                ionice,
            ord('I'):
                ionice,
            curses.KEY_LEFT:
                lambda: self.adjust_sorting_key(-1),
            curses.KEY_RIGHT:
                lambda: self.adjust_sorting_key(1),
            curses.KEY_HOME:
                lambda: self.adjust_sorting_key(-len(IOTopUI.sorting_keys)),
            curses.KEY_END:
                lambda: self.adjust_sorting_key(len(IOTopUI.sorting_keys))
        }

        action = key_bindings.get(key, lambda: None)
        action()

    def get_data(self):
        def format(p):
            stats = format_stats(self.options, p, self.process_list.duration)
            io_delay, swapin_delay, read_bytes, write_bytes = stats
            if Stats.has_blkio_delay_total:
                delay_stats = '%7s %7s ' % (swapin_delay, io_delay)
            else:
                delay_stats = ' ?unavailable?  '
            pid_format = '%%%dd' % MAX_PID_WIDTH
            line = (pid_format + ' %4s %-8s %11s %11s %s') % (
                p.pid, p.get_ioprio(), p.get_user()[:8], read_bytes,
                write_bytes, delay_stats)
            cmdline = p.get_cmdline()
            if not self.options.batch:
                remaining_length = self.width - len(line)
                if 2 < remaining_length < len(cmdline):
                    len1 = (remaining_length - 1) // 2
                    offset2 = -(remaining_length - len1 - 1)
                    cmdline = cmdline[:len1] + '~' + cmdline[offset2:]
            line += cmdline
            if not self.options.batch:
                line = line[:self.width]
            return line

        def should_format(p):
            return not self.options.only or \
                   p.did_some_io(self.options.accumulated)

        processes = list(filter(should_format,
                                self.process_list.processes.values()))
        key = IOTopUI.sorting_keys[self.sorting_key][0]
        if self.options.accumulated:
            stats_lambda = lambda p: p.stats_accum
        else:
            stats_lambda = lambda p: p.stats_delta
        processes.sort(key=lambda p: key(p, stats_lambda(p)),
                       reverse=self.sorting_reverse)
        if not self.options.batch:
            del processes[self.height - 2:]
        return list(map(format, processes))

    def refresh_display(self, first_time, total, actual, duration):
        summary = [
                'Total DISK READ : %s | Total DISK WRITE : %s' % (
                format_bandwidth(self.options, total[0], duration).rjust(14),
                format_bandwidth(self.options, total[1], duration).rjust(14)),
                'Actual DISK READ: %s | Actual DISK WRITE: %s' % (
                format_bandwidth(self.options, actual[0], duration).rjust(14),
                format_bandwidth(self.options, actual[1], duration).rjust(14))
        ]

        pid = max(0, (MAX_PID_WIDTH - 3)) * ' '
        if self.options.processes:
            pid += 'PID'
        else:
            pid += 'TID'
        titles = [pid, '  PRIO', '  USER', '     DISK READ', '  DISK WRITE',
                  '  SWAPIN', '      IO', '    COMMAND']
        lines = self.get_data()
        if self.options.time:
            titles = ['    TIME'] + titles
            current_time = time.strftime('%H:%M:%S ')
            lines = [current_time + l for l in lines]
            summary = [current_time + s for s in summary]
        if self.options.batch:
            if self.options.quiet <= 2:
                for s in summary:
                    print(s)
                if self.options.quiet <= int(first_time):
                    print(''.join(titles))
            for l in lines:
                print(l)
            sys.stdout.flush()
        else:
            self.win.erase()
            for i, s in enumerate(summary):
                self.win.addstr(i, 0, s[:self.width])
            self.win.hline(len(summary), 0, ord(' ') | curses.A_REVERSE,
                           self.width)
            remaining_cols = self.width
            for i in range(len(titles)):
                attr = curses.A_REVERSE
                title = titles[i]
                if i == self.sorting_key:
                    title = title[1:]
                if i == self.sorting_key:
                    attr |= curses.A_BOLD
                    title += self.sorting_reverse and '>' or '<'
                title = title[:remaining_cols]
                remaining_cols -= len(title)
                self.win.addstr(title, attr)
            if Stats.has_blkio_delay_total:
                status_msg = None
            else:
                status_msg = ('CONFIG_TASK_DELAY_ACCT not enabled in kernel, '
                              'cannot determine SWAPIN and IO %')
            num_lines = min(len(lines), self.height - 2 - int(bool(status_msg)))
            for i in range(num_lines):
                try:
                    def print_line(line):
                        self.win.addstr(i + len(summary) + 1, 0, line)
                    try:
                        print_line(lines[i])
                    except UnicodeEncodeError:
                        # Python2: 'ascii' codec can't encode character ...
                        # http://bugs.debian.org/708252
                        print_line(lines[i].encode('utf-8'))
                except curses.error:
                    pass
            if status_msg:
                self.win.insstr(self.height - len(summary), 0, status_msg,
                                curses.A_BOLD)
            self.win.refresh()

def run_iotop_window(win, options):
    if options.batch:
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    else:
        def clean_exit(*args, **kwargs):
            sys.exit(0)
        signal.signal(signal.SIGINT, clean_exit)
        signal.signal(signal.SIGTERM, clean_exit)
    taskstats_connection = TaskStatsNetlink(options)
    process_list = ProcessList(taskstats_connection, options)
    ui = IOTopUI(win, process_list, options)
    ui.run()

def run_iotop(options):
    try:
        if options.batch:
            return run_iotop_window(None, options)
        else:
            return curses.wrapper(run_iotop_window, options)
    except OSError as e:
        if e.errno == errno.EPERM:
            print(e, file=sys.stderr)
            print('''
The Linux kernel interfaces that iotop relies on now require root priviliges
or the NET_ADMIN capability. This change occured because a security issue
(CVE-2011-2494) was found that allows leakage of sensitive data across user
boundaries. If you require the ability to run iotop as a non-root user, please
configure sudo to allow you to run iotop as root.

Please do not file bugs on iotop about this.''', file=sys.stderr)
            sys.exit(1)
        else:
            raise

#
# Profiling
#

def _profile(continuation):
    prof_file = 'iotop.prof'
    try:
        import cProfile
        import pstats
        print('Profiling using cProfile')
        cProfile.runctx('continuation()', globals(), locals(), prof_file)
        stats = pstats.Stats(prof_file)
    except ImportError:
        import hotshot
        import hotshot.stats
        prof = hotshot.Profile(prof_file, lineevents=1)
        print('Profiling using hotshot')
        prof.runcall(continuation)
        prof.close()
        stats = hotshot.stats.load(prof_file)
    stats.strip_dirs()
    stats.sort_stats('time', 'calls')
    stats.print_stats(50)
    stats.print_callees(50)
    os.remove(prof_file)

#
# Main program
#

USAGE = '''%s [OPTIONS]

DISK READ and DISK WRITE are the block I/O bandwidth used during the sampling
period. SWAPIN and IO are the percentages of time the thread spent respectively
while swapping in and waiting on I/O more generally. PRIO is the I/O priority at
which the thread is running (set using the ionice command).

Controls: left and right arrows to change the sorting column, r to invert the
sorting order, o to toggle the --only option, p to toggle the --processes
option, a to toggle the --accumulated option, i to change I/O priority, q to
quit, any other key to force a refresh.''' % sys.argv[0]

def main():
    try:
        locale.setlocale(locale.LC_ALL, '')
    except locale.Error:
        print('unable to set locale, falling back to the default locale')
    parser = optparse.OptionParser(usage=USAGE, version='iotop ' + VERSION)
    parser.add_option('-o', '--only', action='store_true',
                      dest='only', default=False,
                      help='only show processes or threads actually doing I/O')
    parser.add_option('-b', '--batch', action='store_true', dest='batch',
                      help='non-interactive mode')
    parser.add_option('-n', '--iter', type='int', dest='iterations',
                      metavar='NUM',
                      help='number of iterations before ending [infinite]')
    parser.add_option('-d', '--delay', type='float', dest='delay_seconds',
                      help='delay between iterations [1 second]',
                      metavar='SEC', default=1)
    parser.add_option('-p', '--pid', type='int', dest='pids', action='append',
                      help='processes/threads to monitor [all]', metavar='PID')
    parser.add_option('-u', '--user', type='str', dest='users', action='append',
                      help='users to monitor [all]', metavar='USER')
    parser.add_option('-P', '--processes', action='store_true',
                      dest='processes', default=False,
                      help='only show processes, not all threads')
    parser.add_option('-a', '--accumulated', action='store_true',
                      dest='accumulated', default=False,
                      help='show accumulated I/O instead of bandwidth')
    parser.add_option('-k', '--kilobytes', action='store_true',
                      dest='kilobytes', default=False,
                      help='use kilobytes instead of a human friendly unit')
    parser.add_option('-t', '--time', action='store_true', dest='time',
                      help='add a timestamp on each line (implies --batch)')
    parser.add_option('-q', '--quiet', action='count', dest='quiet', default=0,
                      help='suppress some lines of header (implies --batch)')
    parser.add_option('--profile', action='store_true', dest='profile',
                      default=False, help=optparse.SUPPRESS_HELP)

    options, args = parser.parse_args()
    if args:
        parser.error('Unexpected arguments: ' + ' '.join(args))
    find_uids(options)
    options.pids = options.pids or []
    options.batch = options.batch or options.time or options.quiet

    main_loop = lambda: run_iotop(options)

    if options.profile:
        def safe_main_loop():
            try:
                main_loop()
            except:
                pass
        _profile(safe_main_loop)
    else:
        main_loop()

