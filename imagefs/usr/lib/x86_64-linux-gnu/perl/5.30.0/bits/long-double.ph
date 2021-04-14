require '_h2ph_pre.ph';

no warnings qw(redefine misc);

eval 'sub __LONG_DOUBLE_USES_FLOAT128 () {0;}' unless defined(&__LONG_DOUBLE_USES_FLOAT128);
1;
