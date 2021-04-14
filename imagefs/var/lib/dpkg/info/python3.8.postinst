#! /bin/sh

set -e

case "$1" in
    configure)
    files=$(dpkg -L libpython3.8-stdlib:amd64 | sed -n '/^\/usr\/lib\/python3.8\/.*\.py$/p')
    if [ -n "$files" ]; then
	/usr/bin/python3.8 -E -S /usr/lib/python3.8/py_compile.py $files
	if grep -sq '^byte-compile[^#]*optimize' /etc/python/debian_config; then
	    /usr/bin/python3.8 -E -S -O /usr/lib/python3.8/py_compile.py $files
	fi
    else
	echo >&2 "python3.8: can't get files for byte-compilation"
    fi
esac



exit 0
