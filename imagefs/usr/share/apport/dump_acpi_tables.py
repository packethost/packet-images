#!/usr/bin/python3

import os, sys, stat


def dump_acpi_table(filename, tablename, out):
    '''Dump a single ACPI table'''

    if not os.access(filename, os.R_OK):
        return

    out.write('%s @ 0x0000000000000000\n' % tablename[0:4])
    n = 0
    f = open(filename, 'rb')
    hex_str = ''
    try:
        byte = f.read(1)
        while byte != b'':
            val = ord(byte)
            if (n & 15) == 0:
                if (n > 65535):
                    hex_str = '   %4.4X: ' % n
                else:
                    hex_str = '    %4.4X: ' % n
                ascii_str = ''

            hex_str = hex_str + '%2.2X ' % val

            if (val < 32) or (val > 126):
                ascii_str = ascii_str + '.'
            else:
                ascii_str = ascii_str + chr(val)
            n = n + 1
            if (n & 15) == 0:
                out.write('%s %s\n' % (hex_str, ascii_str))
            byte = f.read(1)
    finally:
        if (n % 16) != 0:
            for i in range(n & 15, 16):
                hex_str = hex_str + '   '

            out.write('%s %s\n' % (hex_str, ascii_str))

        f.close()
    out.write('\n')


def dump_acpi_tables(path, out):
    '''Dump ACPI tables'''

    tables = os.listdir(path)
    for tablename in tables:
        pathname = os.path.join(path, tablename)
        mode = os.stat(pathname).st_mode
        if stat.S_ISDIR(mode):
            dump_acpi_tables(pathname, out)
        else:
            dump_acpi_table(pathname, tablename, out)


if os.path.isdir('/sys/firmware/acpi/tables'):
    dump_acpi_tables('/sys/firmware/acpi/tables', sys.stdout)
