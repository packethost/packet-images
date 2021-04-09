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

import errno
import os
import pprint
import pwd
import stat
import struct
import sys
import time

#
# Check for requirements:
#   o Linux >= 2.6.20 with I/O accounting and VM event counters
#

ioaccounting = os.path.exists('/proc/self/io')

try:
    from iotop.vmstat import VmStat
    vmstat_f = VmStat()
except:
    vm_event_counters = False
else:
    vm_event_counters = True

if not ioaccounting or not vm_event_counters:
    print('Could not run iotop as some of the requirements are not met:')
    print('- Linux >= 2.6.20 with')
    if not ioaccounting:
        print('  - I/O accounting support ' \
          '(CONFIG_TASKSTATS, CONFIG_TASK_DELAY_ACCT, ' \
          'CONFIG_TASK_IO_ACCOUNTING)')
    if not vm_event_counters:
        print('  - VM event counters (CONFIG_VM_EVENT_COUNTERS)')
    sys.exit(1)

from iotop import ioprio, vmstat
from iotop.netlink import Connection, NETLINK_GENERIC, U32Attr, NLM_F_REQUEST
from iotop.genetlink import Controller, GeNlMessage

class DumpableObject(object):
    """Base class for all objects that allows easy introspection when printed"""
    def __repr__(self):
        return '%s: %s>' % (str(type(self))[:-1], pprint.pformat(self.__dict__))


#
# Interesting fields in a taskstats output
#

class Stats(DumpableObject):
    members_offsets = [
        ('blkio_delay_total', 40),
        ('swapin_delay_total', 56),
        ('read_bytes', 248),
        ('write_bytes', 256),
        ('cancelled_write_bytes', 264)
    ]

    has_blkio_delay_total = False

    def __init__(self, task_stats_buffer):
        sd = self.__dict__
        for name, offset in Stats.members_offsets:
            data = task_stats_buffer[offset:offset + 8]
            sd[name] = struct.unpack('Q', data)[0]

        # This is a heuristic to detect if CONFIG_TASK_DELAY_ACCT is enabled in
        # the kernel.
        if not Stats.has_blkio_delay_total:
            Stats.has_blkio_delay_total = self.blkio_delay_total != 0

    def accumulate(self, other_stats, destination, coeff=1):
        """Update destination from operator(self, other_stats)"""
        dd = destination.__dict__
        sd = self.__dict__
        od = other_stats.__dict__
        for member, offset in Stats.members_offsets:
            dd[member] = sd[member] + coeff * od[member]

    def delta(self, other_stats, destination):
        """Update destination with self - other_stats"""
        return self.accumulate(other_stats, destination, coeff=-1)

    def is_all_zero(self):
        sd = self.__dict__
        for name, offset in Stats.members_offsets:
            if sd[name] != 0:
                return False
        return True

    @staticmethod
    def build_all_zero():
        stats = Stats.__new__(Stats)
        std = stats.__dict__
        for name, offset in Stats.members_offsets:
            std[name] = 0
        return stats

#
# Netlink usage for taskstats
#

TASKSTATS_CMD_GET = 1
TASKSTATS_CMD_ATTR_PID = 1
TASKSTATS_TYPE_AGGR_PID = 4
TASKSTATS_TYPE_PID = 1
TASKSTATS_TYPE_STATS = 3

class TaskStatsNetlink(object):
    # Keep in sync with format_stats() and pinfo.did_some_io()

    def __init__(self, options):
        self.options = options
        self.connection = Connection(NETLINK_GENERIC)
        controller = Controller(self.connection)
        self.family_id = controller.get_family_id('TASKSTATS')

    def build_request(self, tid):
        return GeNlMessage(self.family_id, cmd=TASKSTATS_CMD_GET,
                           attrs=[U32Attr(TASKSTATS_CMD_ATTR_PID, tid)],
                           flags=NLM_F_REQUEST)

    def get_single_task_stats(self, thread):
        thread.task_stats_request.send(self.connection)
        try:
            reply = GeNlMessage.recv(self.connection)
        except OSError as e:
            if e.errno == errno.ESRCH:
                # OSError: Netlink error: No such process (3)
                return
            raise
        for attr_type, attr_value in reply.attrs.items():
            if attr_type == TASKSTATS_TYPE_AGGR_PID:
                reply = attr_value.nested()
                break
        else:
            return
        taskstats_data = reply[TASKSTATS_TYPE_STATS].data
        if len(taskstats_data) < 272:
            # Short reply
            return
        taskstats_version = struct.unpack('H', taskstats_data[:2])[0]
        assert taskstats_version >= 4
        return Stats(taskstats_data)

#
# PIDs manipulations
#

def find_uids(options):
    """Build options.uids from options.users by resolving usernames to UIDs"""
    options.uids = []
    error = False
    for u in options.users or []:
        try:
            uid = int(u)
        except ValueError:
            try:
                passwd = pwd.getpwnam(u)
            except KeyError:
                print('Unknown user:', u, file=sys.stderr)
                error = True
            else:
                uid = passwd.pw_uid
        if not error:
            options.uids.append(uid)
    if error:
        sys.exit(1)


def parse_proc_pid_status(pid):
    result_dict = {}
    try:
        for line in open('/proc/%d/status' % pid):
            key, value = line.split(':\t', 1)
            result_dict[key] = value.strip()
    except IOError:
        pass  # No such process
    return result_dict


def safe_utf8_decode(s):
    try:
        return s.decode('utf-8')
    except UnicodeDecodeError:
        return s.encode('string_escape')
    except AttributeError:
        return s

class ThreadInfo(DumpableObject):
    """Stats for a single thread"""
    def __init__(self, tid, taskstats_connection):
        self.tid = tid
        self.mark = True
        self.stats_total = None
        self.stats_delta = Stats.__new__(Stats)
        self.task_stats_request = taskstats_connection.build_request(tid)

    def get_ioprio(self):
        return ioprio.get(self.tid)

    def set_ioprio(self, ioprio_class, ioprio_data):
        return ioprio.set_ioprio(ioprio.IOPRIO_WHO_PROCESS, self.tid,
                                 ioprio_class, ioprio_data)

    def update_stats(self, stats):
        if not self.stats_total:
            self.stats_total = stats
        stats.delta(self.stats_total, self.stats_delta)
        self.stats_total = stats


class ProcessInfo(DumpableObject):
    """Stats for a single process (a single line in the output): if
    options.processes is set, it is a collection of threads, otherwise a single
    thread."""
    def __init__(self, pid):
        self.pid = pid
        self.uid = None
        self.user = None
        self.threads = {} # {tid: ThreadInfo}
        self.stats_delta = Stats.build_all_zero()
        self.stats_accum = Stats.build_all_zero()
        self.stats_accum_timestamp = time.time()

    def is_monitored(self, options):
        if (options.pids and not options.processes and
            self.pid not in options.pids):
            # We only monitor some threads, not this one
            return False

        if options.uids and self.get_uid() not in options.uids:
            # We only monitor some users, not this one
            return False

        return True

    def get_uid(self):
        if self.uid:
            return self.uid
        # uid in (None, 0) means either we don't know the UID yet or the process
        # runs as root so it can change its UID. In both cases it means we have
        # to find out its current UID.
        try:
            uid = os.stat('/proc/%d' % self.pid)[stat.ST_UID]
        except OSError:
            # The process disappeared
            uid = None
        if uid != self.uid:
            # Maybe the process called setuid()
            self.user = None
            self.uid = uid
        return uid

    def get_user(self):
        uid = self.get_uid()
        if uid is not None and not self.user:
            try:
                self.user = safe_utf8_decode(pwd.getpwuid(uid).pw_name)
            except (KeyError, AttributeError):
                self.user = str(uid)
        return self.user or '{none}'

    def get_cmdline(self):
        # A process may exec, so we must always reread its cmdline
        try:
            proc_cmdline = open('/proc/%d/cmdline' % self.pid)
            cmdline = proc_cmdline.read(4096)
        except IOError:
            return '{no such process}'
        proc_status = parse_proc_pid_status(self.pid)
        if not cmdline:
            # Probably a kernel thread, get its name from /proc/PID/status
            proc_status_name = proc_status.get('Name', '')
            if proc_status_name:
                proc_status_name = '[%s]' % proc_status_name
            else:
                proc_status_name = '{no name}'
            return proc_status_name
        suffix = ''
        tgid = int(proc_status.get('Tgid', self.pid))
        if tgid != self.pid:
            # Not the main thread, maybe it has a custom name
            tgid_name = parse_proc_pid_status(tgid).get('Name', '')
            thread_name = proc_status.get('Name', '')
            if thread_name != tgid_name:
                suffix += ' [%s]' % thread_name
        parts = cmdline.split('\0')
        if parts[0].startswith('/'):
            first_command_char = parts[0].rfind('/') + 1
            parts[0] = parts[0][first_command_char:]
        cmdline = ' '.join(parts).strip()
        return safe_utf8_decode(cmdline + suffix)

    def did_some_io(self, accumulated):
        if accumulated:
            return not self.stats_accum.is_all_zero()
        for t in self.threads.values():
            if not t.stats_delta.is_all_zero():
                return True
        return False

    def get_ioprio(self):
        priorities = set(t.get_ioprio() for t in self.threads.values())
        if len(priorities) == 1:
            return priorities.pop()
        return '?dif'

    def set_ioprio(self, ioprio_class, ioprio_data):
        for thread in self.threads.values():
            thread.set_ioprio(ioprio_class, ioprio_data)

    def ioprio_sort_key(self):
        return ioprio.sort_key(self.get_ioprio())

    def get_thread(self, tid, taskstats_connection):
        thread = self.threads.get(tid, None)
        if not thread:
            thread = ThreadInfo(tid, taskstats_connection)
            self.threads[tid] = thread
        return thread

    def update_stats(self):
        stats_delta = Stats.build_all_zero()
        for tid, thread in self.threads.items():
            if not thread.mark:
                stats_delta.accumulate(thread.stats_delta, stats_delta)
        self.threads = dict([(tid, thread) for tid, thread in
                             self.threads.items() if not thread.mark])

        nr_threads = len(self.threads)
        if not nr_threads:
            return False

        stats_delta.blkio_delay_total /= nr_threads
        stats_delta.swapin_delay_total /= nr_threads

        self.stats_delta = stats_delta
        self.stats_accum.accumulate(self.stats_delta, self.stats_accum)

        return True

class ProcessList(DumpableObject):
    def __init__(self, taskstats_connection, options):
        # {pid: ProcessInfo}
        self.processes = {}
        self.taskstats_connection = taskstats_connection
        self.options = options
        self.timestamp = time.time()
        self.vmstat = vmstat.VmStat()

        # A first time as we are interested in the delta
        self.update_process_counts()

    def get_process(self, pid):
        """Either get the specified PID from self.processes or build a new
        ProcessInfo if we see this PID for the first time"""
        process = self.processes.get(pid, None)
        if not process:
            process = ProcessInfo(pid)
            self.processes[pid] = process

        if process.is_monitored(self.options):
            return process

    def list_tgids(self):
        if self.options.pids:
            return self.options.pids

        tgids = os.listdir('/proc')
        if self.options.processes:
            return [int(tgid) for tgid in tgids if '0' <= tgid[0] <= '9']

        tids = []
        for tgid in tgids:
            if '0' <= tgid[0] <= '9':
                try:
                    tids.extend(map(int, os.listdir('/proc/' + tgid + '/task')))
                except OSError:
                    # The PID went away
                    pass
        return tids

    def list_tids(self, tgid):
        if not self.options.processes:
            return [tgid]

        try:
            tids = list(map(int, os.listdir('/proc/%d/task' % tgid)))
        except OSError:
            return []

        if self.options.pids:
            tids = list(set(self.options.pids).intersection(set(tids)))

        return tids

    def update_process_counts(self):
        new_timestamp = time.time()
        self.duration = new_timestamp - self.timestamp
        self.timestamp = new_timestamp

        total_read = total_write = 0

        for tgid in self.list_tgids():
            process = self.get_process(tgid)
            if not process:
                continue
            for tid in self.list_tids(tgid):
                thread = process.get_thread(tid, self.taskstats_connection)
                stats = self.taskstats_connection.get_single_task_stats(thread)
                if stats:
                    thread.update_stats(stats)
                    delta = thread.stats_delta
                    total_read += delta.read_bytes
                    total_write += delta.write_bytes
                    thread.mark = False
        return (total_read, total_write), self.vmstat.delta()

    def refresh_processes(self):
        for process in self.processes.values():
            for thread in process.threads.values():
                thread.mark = True

        total_read_and_write = self.update_process_counts()

        self.processes = dict([(pid, process) for pid, process in
                               self.processes.items() if
                               process.update_stats()])

        return total_read_and_write

    def clear(self):
        self.processes = {}
