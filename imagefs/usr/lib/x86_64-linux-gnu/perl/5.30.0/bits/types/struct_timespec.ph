require '_h2ph_pre.ph';

no warnings qw(redefine misc);

unless(defined(&_STRUCT_TIMESPEC)) {
    eval 'sub _STRUCT_TIMESPEC () {1;}' unless defined(&_STRUCT_TIMESPEC);
    require 'bits/types.ph';
    require 'bits/endian.ph';
    if((defined(&__WORDSIZE) ? &__WORDSIZE : undef) == 64|| (defined (&__SYSCALL_WORDSIZE)  && (defined(&__SYSCALL_WORDSIZE) ? &__SYSCALL_WORDSIZE : undef) == 64) || (defined(&__TIMESIZE) ? &__TIMESIZE : undef) == 32) {
    } else {
	if((defined(&__BYTE_ORDER) ? &__BYTE_ORDER : undef) == (defined(&__BIG_ENDIAN) ? &__BIG_ENDIAN : undef)) {
	} else {
	}
    }
}
1;
