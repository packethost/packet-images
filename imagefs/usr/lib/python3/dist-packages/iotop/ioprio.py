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

import ctypes
import fnmatch
import os
import platform

# From http://git.kernel.org/?p=utils/util-linux-ng/util-linux-ng.git;a=blob;
#      f=configure.ac;h=770eb45ae85d32757fc3cff1d70a7808a627f9f7;hb=HEAD#l354
# i386 bit userspace under an x86_64 kernel will have its uname() appear as
# 'x86_64' but it will use the i386 syscall number, that's why we consider both
# the architecture name and the word size.
IOPRIO_GET_ARCH_SYSCALL = [
    ('alpha',       '*',  443),
    ('arm*',        '*',  315),
    ('i*86',        '*',  290),
    ('ia64*',       '*', 1275),
    ('parisc*',     '*',  268),
    ('powerpc*',    '*',  274),
    ('s390*',       '*',  283),
    ('sparc*',      '*',  218),
    ('sh*',         '*',  289),
    ('x86_64*', '32bit',  290),
    ('x86_64*', '64bit',  252),
]

IOPRIO_SET_ARCH_SYSCALL = [
    ('alpha',       '*',  442),
    ('arm*',        '*',  314),
    ('i*86',        '*',  289),
    ('ia64*',       '*', 1274),
    ('parisc*',     '*',  267),
    ('powerpc*',    '*',  273),
    ('s390*',       '*',  282),
    ('sparc*',      '*',  196),
    ('sh*',         '*',  288),
    ('x86_64*',  '32bit', 289),
    ('x86_64*',  '64bit', 251),
]

def find_ioprio_syscall_number(syscall_list):
    arch = os.uname()[4]
    bits = platform.architecture()[0]

    for candidate_arch, candidate_bits, syscall_nr in syscall_list:
        if fnmatch.fnmatch(arch, candidate_arch) and \
           fnmatch.fnmatch(bits, candidate_bits):
            return syscall_nr

class IoprioSetError(Exception):
    def __init__(self, err):
        try:
            self.err = os.strerror(err)
        except TypeError:
            self.err = err

__NR_ioprio_get = find_ioprio_syscall_number(IOPRIO_GET_ARCH_SYSCALL)
__NR_ioprio_set = find_ioprio_syscall_number(IOPRIO_SET_ARCH_SYSCALL)

try:
    ctypes_handle = ctypes.CDLL(None, use_errno=True)
except TypeError:
    ctypes_handle = ctypes.CDLL(None)

syscall = ctypes_handle.syscall

PRIORITY_CLASSES = [None, 'rt', 'be', 'idle']

IOPRIO_WHO_PROCESS = 1
IOPRIO_CLASS_SHIFT = 13
IOPRIO_PRIO_MASK = (1 << IOPRIO_CLASS_SHIFT) - 1

def ioprio_value(ioprio_class, ioprio_data):
    try:
        ioprio_class = PRIORITY_CLASSES.index(ioprio_class)
    except ValueError:
        ioprio_class = PRIORITY_CLASSES.index(None)
    return (ioprio_class << IOPRIO_CLASS_SHIFT) | ioprio_data

def ioprio_class(ioprio):
    return PRIORITY_CLASSES[ioprio >> IOPRIO_CLASS_SHIFT]

def ioprio_data(ioprio):
    return ioprio & IOPRIO_PRIO_MASK

sched_getscheduler = ctypes_handle.sched_getscheduler
SCHED_OTHER, SCHED_FIFO, SCHED_RR, SCHED_BATCH, SCHED_ISO, SCHED_IDLE = range(6)

getpriority = ctypes_handle.getpriority
PRIO_PROCESS = 0

def get_ioprio_from_sched(pid):
    scheduler = sched_getscheduler(pid)
    nice = getpriority(PRIO_PROCESS, pid)
    ioprio_nice = (nice + 20) / 5

    if scheduler in (SCHED_FIFO, SCHED_RR):
        return 'rt/%d' % ioprio_nice
    elif scheduler == SCHED_IDLE:
        return 'idle'
    else:
        return 'be/%d' % ioprio_nice

def get(pid):
    if __NR_ioprio_get is None:
        return '?sys'

    ioprio = syscall(__NR_ioprio_get, IOPRIO_WHO_PROCESS, pid)
    if ioprio < 0:
        return '?err'

    prio_class = ioprio_class(ioprio)
    if not prio_class:
        return get_ioprio_from_sched(pid)
    if prio_class == 'idle':
        return prio_class
    return '%s/%d' % (prio_class, ioprio_data(ioprio))

def set_ioprio(which, who, ioprio_class, ioprio_data):
    if __NR_ioprio_set is None:
        raise IoprioSetError('No ioprio_set syscall found')

    ioprio_val = ioprio_value(ioprio_class, ioprio_data)
    ret = syscall(__NR_ioprio_set, which, who, ioprio_val, use_errno=True)
    if ret < 0:
        try:
            err = ctypes.get_errno()
        except AttributeError:
            err = 'Unknown error (errno support not available before Python2.6)'
        raise IoprioSetError(err)

def sort_key(key):
    if key[0] == '?':
        return -ord(key[1])

    if '/' in key:
        if key.startswith('rt/'):
            shift = 0
        elif key.startswith('be/'):
            shift = 1
        prio = int(key.split('/')[1])
    elif key == 'idle':
        shift = 2
        prio = 0

    return (1 << (shift * IOPRIO_CLASS_SHIFT)) + prio

def to_class_and_data(ioprio_str):
    if '/' in ioprio_str:
        split = ioprio_str.split('/')
        return (split[0], int(split[1]))
    elif ioprio_str == 'idle':
        return ('idle', 0)
    return (None, None)

if __name__ == '__main__':
    import sys
    if len(sys.argv) == 2:
        pid = int(sys.argv[1])
    else:
        pid = os.getpid()
    print('pid:', pid)
    print('ioprio:', get(pid))

