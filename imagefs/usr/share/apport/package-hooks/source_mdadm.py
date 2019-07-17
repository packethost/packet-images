'''apport package hook for mdadm

(c) 2009-2016 Canonical Ltd.
Author: Steve Beattie <sbeattie@ubuntu.com>

Based on the ideas in debian's /usr/share/bug/mdadm/script
'''

from apport.hookutils import attach_file, attach_file_if_exists, attach_hardware, path_to_key, command_output
import os
import re
import glob
import gzip
import subprocess
import sys


def get_initrd_files(pattern):
    '''Extract listing of files from the current initrd which match a regex.

       pattern should be a "re" object.  '''

    (_, _, release, _, _) = os.uname()
    try:
        fd = gzip.GzipFile('/boot/initrd.img-' + release, 'rb')
        # universal_newlines needs to be False here as we're passing
        # binary data from gzip into cpio, which means we'll need to
        # decode the bytes into strings later when reading the output
        cpio = subprocess.Popen(['cpio', '-t'], close_fds=True, stderr=subprocess.STDOUT,
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                universal_newlines=False)
    except OSError as e:
        return 'Error: ' + str(e)

    out = cpio.communicate(fd.read())[0].decode(sys.stdout.encoding, errors='replace')
    if cpio.returncode != 0:
        return 'Error: command %s failed with exit code %i %' % (
            'cpio', cpio.returncode, out)

    lines = ''.join([l for l in out.splitlines(True) if pattern.search(l)])
    return lines


def add_info(report):
    attach_hardware(report)
    attach_file(report, '/proc/mounts', 'ProcMounts')
    attach_file_if_exists(report, '/etc/mdadm/mdadm.conf', 'mdadm.conf')
    attach_file(report, '/proc/mdstat', 'ProcMDstat')
    attach_file(report, '/proc/partitions', 'ProcPartitions')
    attach_file(report, '/etc/blkid.tab', 'etc.blkid.tab')
    attach_file_if_exists(report, '/boot/grub/menu.lst', 'GrubMenu.lst')
    attach_file_if_exists(report, '/boot/grub/grub.cfg', 'Grub.cfg')
    attach_file_if_exists(report, '/etc/lilo.conf', 'lilo.conf')

    devices = glob.glob("/dev/[hs]d*")
    for dev in devices:
        report['MDadmExamine' + path_to_key(dev)] = command_output(['/sbin/mdadm', '-E', dev])

    initrd_re = re.compile('md[a/]')
    report['initrd.files'] = get_initrd_files(initrd_re)
