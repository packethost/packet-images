# dialog_apt_key.py.in - edit the apt keys
#  
#  Copyright (c) 2004 Canonical
#  
#  Author: Michael Vogt <mvo@debian.org>
# 
#  This program is free software; you can redistribute it and/or 
#  modify it under the terms of the GNU General Public License as 
#  published by the Free Software Foundation; either version 2 of the
#  License, or (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
#  USA

from __future__ import print_function

import atexit
import gettext
import os
import shutil
import subprocess
import tempfile

from subprocess import PIPE

# gettext convenient
_ = gettext.gettext
def dummy(e): return e
N_ = dummy

# some known keys
N_("Ubuntu Archive Automatic Signing Key <ftpmaster@ubuntu.com>")
N_("Ubuntu CD Image Automatic Signing Key <cdimage@ubuntu.com>")
N_("Ubuntu Archive Automatic Signing Key (2012) <ftpmaster@ubuntu.com>")
N_("Ubuntu CD Image Automatic Signing Key (2012) <cdimage@ubuntu.com>")
N_("Ubuntu Extras Archive Automatic Signing Key <ftpmaster@ubuntu.com>")

class AptAuth:
    def __init__(self, rootdir="/"):
        self.gpg = ["/usr/bin/gpg"]
        self.base_opt = self.gpg + [
            "--no-options", 
            "--no-default-keyring",
            "--no-auto-check-trustdb",
            "--trust-model", "always",
            "--keyring", os.path.join(rootdir, "etc/apt/trusted.gpg"),
            ]
        self.tmpdir = tempfile.mkdtemp()
        self.base_opt += ["--secret-keyring", 
                          os.path.join(self.tmpdir, "secring.gpg")]
        self.list_opt = self.base_opt + ["--with-colons",
                                         "--batch",
                                         "--list-keys"]
        self.rm_opt = self.base_opt + ["--quiet",
                                       "--batch",
                                       "--delete-key",
                                       "--yes"]
        self.add_opt = self.base_opt + ["--quiet", 
                                        "--batch",
                                        "--import"]
        atexit.register(self._cleanup_tmpdir)

    def _cleanup_tmpdir(self):
        shutil.rmtree(self.tmpdir)
       
    def list(self):
        res = []
        #print(self.list_opt)
        p = subprocess.Popen(
            self.list_opt, stdout=PIPE, universal_newlines=True).stdout
        for line in p:
            fields = line.split(":")
            if fields[0] == "pub":
                name = fields[9]
                res.append("%s %s\n%s" %((fields[4])[-8:],fields[5], _(name)))
        p.close()
        return res

    def add(self, filename):
        #print("request to add " + filename)
        cmd = self.add_opt[:]
        cmd.append(filename)
        #print("cmd is: %s" % ' '.join(cmd))
        p = subprocess.Popen(cmd)
        return (p.wait() == 0)
        
    def update(self):
        cmd = ["/usr/bin/apt-key", "update"]
        p = subprocess.Popen(cmd)
        return (p.wait() == 0)

    def rm(self, key):
        #print("request to remove " + key)
        cmd = self.rm_opt[:]
        cmd.append(key)
        p = subprocess.Popen(cmd)
        return (p.wait() == 0)
