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

class VmStat(object):
    def __init__(self):
        self.vmstat_file = open('/proc/vmstat')
        self.vmstat = self.read()

    def read(self):
        def extract(line):
            return int(line.split()[1]) * 1024

        for line in self.vmstat_file:
            if line.startswith('pgpgin '):
                pgpgin = extract(line)
                break

        for line in self.vmstat_file:
            if line.startswith('pgpgout '):
                pgpgout = extract(line)
                break

        self.vmstat_file.seek(0)
        return pgpgin, pgpgout

    def delta(self):
        now = self.read()
        delta = now[0] - self.vmstat[0], now[1] - self.vmstat[1]
        self.vmstat = now
        return delta

