# ubuntu-release-upgrader related problems
# Author: Brian Murray <brian.murray@canonical.com>
# (C) 2020 Canonical Ltd.
# License: GPL v3 or later.

import os

def run(report, ui):
    with os.scandir('/var/log/installer') as entries:
        for entry in entries:
            if entry.name.startswith('subiquity'):
                return 'subiquity'
            elif entry.name == 'telemetry':
                return 'ubiquity'
            # d-i leaves a few unique things including
            # lsb-release, hardware-summary, status
            elif entry.name == 'status':
                return 'debian-installer'
