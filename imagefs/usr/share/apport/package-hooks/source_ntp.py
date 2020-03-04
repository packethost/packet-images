'''apport package hook for ntp

(c) 2010-2011 Canonical Ltd.
Author: Chuck Short <zulcss@ubuntu.com>
'''

from apport.hookutils import *
from os import path
import re

def add_info(report):
	attach_conffiles(report, 'ntp')

	# get apparmor stuff
	attach_mac_events(report, '/usr/sbin/ntpd')
	attach_file(report, '/etc/apparmor.d/usr.sbin.ntpd')

	# get syslog stuff
	recent_syslog(re.compile(r'ntpd\['))

	# Get debug information
	report['NtpStatus'] = command_output(['ntpq', '-p'])
