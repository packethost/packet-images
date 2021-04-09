cmd_scripts/selinux/genheaders/genheaders := gcc -Wp,-MD,scripts/selinux/genheaders/.genheaders.d -Iscripts/selinux/genheaders -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89  -I/build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi  -I/build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include  -I/build/linux-hwe-dLKN2F/linux-hwe-4.15.0/security/selinux/include -o scripts/selinux/genheaders/genheaders /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/scripts/selinux/genheaders/genheaders.c  

source_scripts/selinux/genheaders/genheaders := /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/scripts/selinux/genheaders/genheaders.c

deps_scripts/selinux/genheaders/genheaders := \
  /usr/include/stdc-predef.h \
  /usr/include/stdio.h \
  /usr/include/features.h \
  /usr/include/x86_64-linux-gnu/sys/cdefs.h \
  /usr/include/x86_64-linux-gnu/bits/wordsize.h \
  /usr/include/x86_64-linux-gnu/gnu/stubs.h \
  /usr/include/x86_64-linux-gnu/gnu/stubs-64.h \
  /usr/lib/gcc/x86_64-linux-gnu/5/include/stddef.h \
  /usr/include/x86_64-linux-gnu/bits/types.h \
  /usr/include/x86_64-linux-gnu/bits/typesizes.h \
  /usr/include/libio.h \
  /usr/include/_G_config.h \
  /usr/include/wchar.h \
  /usr/lib/gcc/x86_64-linux-gnu/5/include/stdarg.h \
  /usr/include/x86_64-linux-gnu/bits/stdio_lim.h \
  /usr/include/x86_64-linux-gnu/bits/sys_errlist.h \
  /usr/include/x86_64-linux-gnu/bits/stdio.h \
  /usr/include/x86_64-linux-gnu/bits/stdio2.h \
  /usr/include/stdlib.h \
  /usr/include/x86_64-linux-gnu/bits/waitflags.h \
  /usr/include/x86_64-linux-gnu/bits/waitstatus.h \
  /usr/include/endian.h \
  /usr/include/x86_64-linux-gnu/bits/endian.h \
  /usr/include/x86_64-linux-gnu/bits/byteswap.h \
  /usr/include/x86_64-linux-gnu/bits/byteswap-16.h \
  /usr/include/x86_64-linux-gnu/sys/types.h \
  /usr/include/time.h \
  /usr/include/x86_64-linux-gnu/sys/select.h \
  /usr/include/x86_64-linux-gnu/bits/select.h \
  /usr/include/x86_64-linux-gnu/bits/sigset.h \
  /usr/include/x86_64-linux-gnu/bits/time.h \
  /usr/include/x86_64-linux-gnu/bits/select2.h \
  /usr/include/x86_64-linux-gnu/sys/sysmacros.h \
  /usr/include/x86_64-linux-gnu/bits/pthreadtypes.h \
  /usr/include/alloca.h \
  /usr/include/x86_64-linux-gnu/bits/stdlib-bsearch.h \
  /usr/include/x86_64-linux-gnu/bits/stdlib-float.h \
  /usr/include/x86_64-linux-gnu/bits/stdlib.h \
  /usr/include/unistd.h \
  /usr/include/x86_64-linux-gnu/bits/posix_opt.h \
  /usr/include/x86_64-linux-gnu/bits/environments.h \
  /usr/include/x86_64-linux-gnu/bits/confname.h \
  /usr/include/getopt.h \
  /usr/include/x86_64-linux-gnu/bits/unistd.h \
  /usr/include/string.h \
  /usr/include/xlocale.h \
  /usr/include/x86_64-linux-gnu/bits/string.h \
  /usr/include/x86_64-linux-gnu/bits/string2.h \
  /usr/include/x86_64-linux-gnu/bits/string3.h \
  /usr/include/errno.h \
  /usr/include/x86_64-linux-gnu/bits/errno.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/linux/errno.h \
  /usr/include/x86_64-linux-gnu/asm/errno.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/asm-generic/errno.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/asm-generic/errno-base.h \
  /usr/include/ctype.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/security/selinux/include/classmap.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/linux/capability.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/linux/types.h \
  /usr/include/x86_64-linux-gnu/asm/types.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/asm-generic/types.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/asm-generic/int-ll64.h \
  /usr/include/x86_64-linux-gnu/asm/bitsperlong.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/asm-generic/bitsperlong.h \
    $(wildcard include/config/64bit.h) \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/linux/posix_types.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/linux/stddef.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/linux/compiler_types.h \
    $(wildcard include/config/have/arch/compiler/h.h) \
    $(wildcard include/config/enable/must/check.h) \
    $(wildcard include/config/enable/warn/deprecated.h) \
  /usr/include/x86_64-linux-gnu/asm/posix_types.h \
  /usr/include/x86_64-linux-gnu/asm/posix_types_64.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/asm-generic/posix_types.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi/linux/socket.h \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/security/selinux/include/initial_sid_to_string.h \

scripts/selinux/genheaders/genheaders: $(deps_scripts/selinux/genheaders/genheaders)

$(deps_scripts/selinux/genheaders/genheaders):
