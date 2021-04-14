#!/usr/bin/python

# vim: fileencoding=utf-8
#
# Copyright (C) 2014       Google, Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

"""Check the format and dumpability of debian/copyright filenames on stdin.

Usage:

    find /tmp/packages -type f -name copyright | ./check_parse_and_dump.py

The --suppress_warnings and --summary flags can be used to make the program
output less verbose.
"""

import argparse
import codecs
import io
import sys
import warnings

from debian import copyright


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--summary', action='store_true',
                        help='Whether to print only a summary')
    parser.add_argument('--suppress_warnings', action='store_true',
                        help='Whether to suppress copyright warnings')
    return parser.parse_args()


def main():
    args = parse_args()

    if args.suppress_warnings:
        warnings.filterwarnings('ignore', module='debian.copyright')

    problems = {}
    parse_failures = []
    dump_failures = []

    total = 0
    for filename in sys.stdin:
        total += 1
        filename = filename.rstrip()
        with io.open(filename, mode='rt', encoding='utf-8') as f:
            try:
                c = copyright.Copyright(f)
            except Exception as e:
                problems.setdefault((1, 'Parse failures'), []).append(
                    (filename, e))
                continue

            try:
                c.dump()
            except Exception as e:
                problems.setdefault((2, 'Dump failures'), []).append(
                    (filename, e))

            if not c.header.known_format():
                problems.setdefault((3, 'Unknown format'), []).append(
                    (filename, c.header.format))

            invalid_globs = []
            globs_with_leading_dot_slash = []
            globs_with_trailing_comma = []
            globs_with_double_star = []
            for p in c.all_files_paragraphs():
                try:
                    p.files_pattern()
                except Exception as e:
                    invalid_globs.append(e)
                for glob in p.files:
                    if glob.startswith('./'):
                        globs_with_leading_dot_slash.append(glob)
                    if glob.endswith(','):
                        globs_with_trailing_comma.append(glob)
                    if '**' in glob:
                        globs_with_double_star.append(glob)

            if invalid_globs:
                problems.setdefault((4, 'Invalid glob'), []).append(
                    (filename, invalid_globs))
            if globs_with_leading_dot_slash:
                problems.setdefault((5, 'Globs with leading ./'), []).append(
                    (filename, globs_with_leading_dot_slash))
            if globs_with_trailing_comma:
                problems.setdefault((6, 'Globs with trailing ,'), []).append(
                    (filename, globs_with_trailing_comma))
            if globs_with_double_star:
                problems.setdefault((7, 'Globs with **'), []).append(
                    (filename, globs_with_double_star))

    f = codecs.getwriter(encoding='utf-8')(sys.stdout)
    for (_, heading), problems in sorted(problems.items()):
        f.write('\n%s: (%d / %d)\n' % (heading, len(problems), total))
        if not args.summary:
            for filename, problem in problems:
                f.write(' %s: %s\n' % (filename, problem))


if __name__ == '__main__':
    main()
