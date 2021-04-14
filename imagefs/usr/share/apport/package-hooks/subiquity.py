'''
Send reports about subiquity to the correct Launchpad project.

'''
import os

from apport import hookutils


def add_info(report, ui):
    # TODO: read the version from the log file?
    logfile = os.path.realpath('/var/log/installer/subiquity-debug.log')
    revision = 'unknown'
    if os.path.exists(logfile):
        hookutils.attach_file(report, 'logfile', 'InstallerLog')
        with open(logfile) as fp:
            first_line = fp.readline()
        marker = 'Starting Subiquity revision'
        if marker in first_line:
            revision = first_line.split(marker)[1].strip()
    report['Package'] = 'subiquity ({})'.format(revision)
    report['SourcePackage'] = 'subiquity'
    # rewrite this section so the report goes to the project in Launchpad
    report['CrashDB'] = '''{
       "impl": "launchpad",
       "project": "subiquity",
       "bug_pattern_url": "http://people.canonical.com/~ubuntu-archive/bugpatterns/bugpatterns.xml"
    }'''

    # add in subiquity stuff
    hookutils.attach_file_if_exists(
        report,
        '/var/log/installer/subiquity-curtin-install.conf',
        'CurtinConfig')
    hookutils.attach_file_if_exists(
        report,
        '/var/log/installer/curtin-install.log',
        'CurtinLog')
    hookutils.attach_file_if_exists(
        report,
        '/var/log/installer/block/probe-data.json',
        'ProbeData')
