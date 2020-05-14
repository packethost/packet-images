require '_h2ph_pre.ph';

no warnings qw(redefine misc);

unless(defined(&_SYS_CDEFS_H)) {
    eval 'sub _SYS_CDEFS_H () {1;}' unless defined(&_SYS_CDEFS_H);
    unless(defined(&_FEATURES_H)) {
	require 'features.ph';
    }
    if(defined (&__GNUC__)  && !defined (&__STDC__)) {
	die("You need a ISO C conforming compiler to use the glibc headers");
    }
    undef(&__P) if defined(&__P);
    undef(&__PMT) if defined(&__PMT);
    if(defined(&__GNUC__)) {
	if( &__GNUC_PREREQ (4, 6)  && !defined (&_LIBC)) {
	    eval 'sub __LEAF () {,  &__leaf__;}' unless defined(&__LEAF);
	    eval 'sub __LEAF_ATTR () { &__attribute__ (( &__leaf__));}' unless defined(&__LEAF_ATTR);
	} else {
	    eval 'sub __LEAF () {1;}' unless defined(&__LEAF);
	    eval 'sub __LEAF_ATTR () {1;}' unless defined(&__LEAF_ATTR);
	}
	if(!defined (&__cplusplus)  &&  &__GNUC_PREREQ (3, 3)) {
	    eval 'sub __THROW () { &__attribute__ (( &__nothrow__  &__LEAF));}' unless defined(&__THROW);
	    eval 'sub __THROWNL () { &__attribute__ (( &__nothrow__));}' unless defined(&__THROWNL);
	    eval 'sub __NTH {
	        my($fct) = @_;
    		eval q( &__attribute__ (( &__nothrow__  &__LEAF)) $fct);
	    }' unless defined(&__NTH);
	} else {
	    if(defined (&__cplusplus)  &&  &__GNUC_PREREQ (2,8)) {
		eval 'sub __THROW () { &throw ();}' unless defined(&__THROW);
		eval 'sub __THROWNL () { &throw ();}' unless defined(&__THROWNL);
		eval 'sub __NTH {
		    my($fct) = @_;
    		    eval q( &__LEAF_ATTR $fct  &throw ());
		}' unless defined(&__NTH);
	    } else {
		eval 'sub __THROW () {1;}' unless defined(&__THROW);
		eval 'sub __THROWNL () {1;}' unless defined(&__THROWNL);
		eval 'sub __NTH {
		    my($fct) = @_;
    		    eval q($fct);
		}' unless defined(&__NTH);
	    }
	}
    } else {
	eval 'sub __inline () {1;}' unless defined(&__inline);
	eval 'sub __THROW () {1;}' unless defined(&__THROW);
	eval 'sub __THROWNL () {1;}' unless defined(&__THROWNL);
	eval 'sub __NTH {
	    my($fct) = @_;
    	    eval q($fct);
	}' unless defined(&__NTH);
    }
    eval 'sub __P {
        my($args) = @_;
	    eval q($args);
    }' unless defined(&__P);
    eval 'sub __PMT {
        my($args) = @_;
	    eval q($args);
    }' unless defined(&__PMT);
    eval 'sub __CONCAT {
        my($x,$y) = @_;
	    eval q($x  $y);
    }' unless defined(&__CONCAT);
    eval 'sub __STRING {
        my($x) = @_;
	    eval q($x);
    }' unless defined(&__STRING);
    eval 'sub __ptr_t () { &void *;}' unless defined(&__ptr_t);
    eval 'sub __long_double_t () {\'long double\';}' unless defined(&__long_double_t);
    if(defined(&__cplusplus)) {
	eval 'sub __BEGIN_DECLS () { &extern "C" {;}' unless defined(&__BEGIN_DECLS);
	eval 'sub __END_DECLS () {};}' unless defined(&__END_DECLS);
    } else {
	eval 'sub __BEGIN_DECLS () {1;}' unless defined(&__BEGIN_DECLS);
	eval 'sub __END_DECLS () {1;}' unless defined(&__END_DECLS);
    }
    if(defined (&__cplusplus)  && defined (&_GLIBCPP_USE_NAMESPACES)) {
	eval 'sub __BEGIN_NAMESPACE_STD () { &namespace  &std {;}' unless defined(&__BEGIN_NAMESPACE_STD);
	eval 'sub __END_NAMESPACE_STD () {};}' unless defined(&__END_NAMESPACE_STD);
	eval 'sub __USING_NAMESPACE_STD {
	    my($name) = @_;
    	    eval q( &using  &std::$name;);
	}' unless defined(&__USING_NAMESPACE_STD);
	eval 'sub __BEGIN_NAMESPACE_C99 () { &namespace  &__c99 {;}' unless defined(&__BEGIN_NAMESPACE_C99);
	eval 'sub __END_NAMESPACE_C99 () {};}' unless defined(&__END_NAMESPACE_C99);
	eval 'sub __USING_NAMESPACE_C99 {
	    my($name) = @_;
    	    eval q( &using  &__c99::$name;);
	}' unless defined(&__USING_NAMESPACE_C99);
    } else {
	eval 'sub __BEGIN_NAMESPACE_STD () {1;}' unless defined(&__BEGIN_NAMESPACE_STD);
	eval 'sub __END_NAMESPACE_STD () {1;}' unless defined(&__END_NAMESPACE_STD);
	eval 'sub __USING_NAMESPACE_STD {
	    my($name) = @_;
    	    eval q();
	}' unless defined(&__USING_NAMESPACE_STD);
	eval 'sub __BEGIN_NAMESPACE_C99 () {1;}' unless defined(&__BEGIN_NAMESPACE_C99);
	eval 'sub __END_NAMESPACE_C99 () {1;}' unless defined(&__END_NAMESPACE_C99);
	eval 'sub __USING_NAMESPACE_C99 {
	    my($name) = @_;
    	    eval q();
	}' unless defined(&__USING_NAMESPACE_C99);
    }
    eval 'sub __bos {
        my($ptr) = @_;
	    eval q( &__builtin_object_size ($ptr,  &__USE_FORTIFY_LEVEL > 1));
    }' unless defined(&__bos);
    eval 'sub __bos0 {
        my($ptr) = @_;
	    eval q( &__builtin_object_size ($ptr, 0));
    }' unless defined(&__bos0);
    if( &__GNUC_PREREQ (4,3)) {
	eval 'sub __warndecl {
	    my($name, $msg) = @_;
    	    eval q( &extern  &void $name ( &void)  &__attribute__(( &__warning__ ($msg))));
	}' unless defined(&__warndecl);
	eval 'sub __warnattr {
	    my($msg) = @_;
    	    eval q( &__attribute__(( &__warning__ ($msg))));
	}' unless defined(&__warnattr);
	eval 'sub __errordecl {
	    my($name, $msg) = @_;
    	    eval q( &extern  &void $name ( &void)  &__attribute__(( &__error__ ($msg))));
	}' unless defined(&__errordecl);
    } else {
	eval 'sub __warndecl {
	    my($name, $msg) = @_;
    	    eval q( &extern  &void $name ( &void));
	}' unless defined(&__warndecl);
	eval 'sub __warnattr {
	    my($msg) = @_;
    	    eval q();
	}' unless defined(&__warnattr);
	eval 'sub __errordecl {
	    my($name, $msg) = @_;
    	    eval q( &extern  &void $name ( &void));
	}' unless defined(&__errordecl);
    }
    if( &__GNUC_PREREQ (2,97)) {
	eval 'sub __flexarr () {[];}' unless defined(&__flexarr);
    } else {
	if(defined(&__GNUC__)) {
	    eval 'sub __flexarr () {[0];}' unless defined(&__flexarr);
	} else {
	    if(defined (&__STDC_VERSION__)  && (defined(&__STDC_VERSION__) ? &__STDC_VERSION__ : undef) >= 199901) {
		eval 'sub __flexarr () {[];}' unless defined(&__flexarr);
	    } else {
		eval 'sub __flexarr () {[1];}' unless defined(&__flexarr);
	    }
	}
    }
    if(defined (&__GNUC__)  && (defined(&__GNUC__) ? &__GNUC__ : undef) >= 2) {
	eval 'sub __REDIRECT {
	    my($name, $proto, $alias) = @_;
    	    eval q(\\"(assembly code)\\");
	}' unless defined(&__REDIRECT);
	if(defined(&__cplusplus)) {
	    eval 'sub __REDIRECT_NTH {
	        my($name, $proto, $alias) = @_;
    		eval q(\\"(assembly code)\\");
	    }' unless defined(&__REDIRECT_NTH);
	    eval 'sub __REDIRECT_NTHNL {
	        my($name, $proto, $alias) = @_;
    		eval q(\\"(assembly code)\\");
	    }' unless defined(&__REDIRECT_NTHNL);
	} else {
	    eval 'sub __REDIRECT_NTH {
	        my($name, $proto, $alias) = @_;
    		eval q(\\"(assembly code)\\");
	    }' unless defined(&__REDIRECT_NTH);
	    eval 'sub __REDIRECT_NTHNL {
	        my($name, $proto, $alias) = @_;
    		eval q(\\"(assembly code)\\");
	    }' unless defined(&__REDIRECT_NTHNL);
	}
	eval 'sub __ASMNAME {
	    my($cname) = @_;
    	    eval q( &__ASMNAME2 ( &__USER_LABEL_PREFIX__, $cname));
	}' unless defined(&__ASMNAME);
	eval 'sub __ASMNAME2 {
	    my($prefix, $cname) = @_;
    	    eval q( &__STRING ($prefix) $cname);
	}' unless defined(&__ASMNAME2);
    }
    if(!defined (&__GNUC__) || (defined(&__GNUC__) ? &__GNUC__ : undef) < 2) {
	eval 'sub __attribute__ {
	    my($xyz) = @_;
    	    eval q();
	}' unless defined(&__attribute__);
    }
    if( &__GNUC_PREREQ (2,96)) {
	eval 'sub __attribute_malloc__ () { &__attribute__ (( &__malloc__));}' unless defined(&__attribute_malloc__);
    } else {
	eval 'sub __attribute_malloc__ () {1;}' unless defined(&__attribute_malloc__);
    }
    if( &__GNUC_PREREQ (4, 3)) {
	eval 'sub __attribute_alloc_size__ {
	    my($params) = @_;
    	    eval q( &__attribute__ (( &__alloc_size__ $params)));
	}' unless defined(&__attribute_alloc_size__);
    } else {
	eval 'sub __attribute_alloc_size__ {
	    my($params) = @_;
    	    eval q();
	}' unless defined(&__attribute_alloc_size__);
    }
    if( &__GNUC_PREREQ (2,96)) {
	eval 'sub __attribute_pure__ () { &__attribute__ (( &__pure__));}' unless defined(&__attribute_pure__);
    } else {
	eval 'sub __attribute_pure__ () {1;}' unless defined(&__attribute_pure__);
    }
    if( &__GNUC_PREREQ (2,5)) {
	eval 'sub __attribute_const__ () { &__attribute__ (( &__const__));}' unless defined(&__attribute_const__);
    } else {
	eval 'sub __attribute_const__ () {1;}' unless defined(&__attribute_const__);
    }
    if( &__GNUC_PREREQ (3,1)) {
	eval 'sub __attribute_used__ () { &__attribute__ (( &__used__));}' unless defined(&__attribute_used__);
	eval 'sub __attribute_noinline__ () { &__attribute__ (( &__noinline__));}' unless defined(&__attribute_noinline__);
    } else {
	eval 'sub __attribute_used__ () { &__attribute__ (( &__unused__));}' unless defined(&__attribute_used__);
	eval 'sub __attribute_noinline__ () {1;}' unless defined(&__attribute_noinline__);
    }
    if( &__GNUC_PREREQ (3,2)) {
	eval 'sub __attribute_deprecated__ () { &__attribute__ (( &__deprecated__));}' unless defined(&__attribute_deprecated__);
    } else {
	eval 'sub __attribute_deprecated__ () {1;}' unless defined(&__attribute_deprecated__);
    }
    if( &__GNUC_PREREQ (2,8)) {
	eval 'sub __attribute_format_arg__ {
	    my($x) = @_;
    	    eval q( &__attribute__ (( &__format_arg__ ($x))));
	}' unless defined(&__attribute_format_arg__);
    } else {
	eval 'sub __attribute_format_arg__ {
	    my($x) = @_;
    	    eval q();
	}' unless defined(&__attribute_format_arg__);
    }
    if( &__GNUC_PREREQ (2,97)) {
	eval 'sub __attribute_format_strfmon__ {
	    my($a,$b) = @_;
    	    eval q( &__attribute__ (( &__format__ ( &__strfmon__, $a, $b))));
	}' unless defined(&__attribute_format_strfmon__);
    } else {
	eval 'sub __attribute_format_strfmon__ {
	    my($a,$b) = @_;
    	    eval q();
	}' unless defined(&__attribute_format_strfmon__);
    }
    if( &__GNUC_PREREQ (3,3)) {
	eval 'sub __nonnull {
	    my($params) = @_;
    	    eval q( &__attribute__ (( &__nonnull__ $params)));
	}' unless defined(&__nonnull);
    } else {
	eval 'sub __nonnull {
	    my($params) = @_;
    	    eval q();
	}' unless defined(&__nonnull);
    }
    if( &__GNUC_PREREQ (3,4)) {
	eval 'sub __attribute_warn_unused_result__ () { &__attribute__ (( &__warn_unused_result__));}' unless defined(&__attribute_warn_unused_result__);
	if((defined(&__USE_FORTIFY_LEVEL) ? &__USE_FORTIFY_LEVEL : undef) > 0) {
	    eval 'sub __wur () { &__attribute_warn_unused_result__;}' unless defined(&__wur);
	}
    } else {
	eval 'sub __attribute_warn_unused_result__ () {1;}' unless defined(&__attribute_warn_unused_result__);
    }
    unless(defined(&__wur)) {
	eval 'sub __wur () {1;}' unless defined(&__wur);
    }
    if( &__GNUC_PREREQ (3,2)) {
	undef(&__always_inline) if defined(&__always_inline);
	eval 'sub __always_inline () { &__inline  &__attribute__ (( &__always_inline__));}' unless defined(&__always_inline);
    } else {
	undef(&__always_inline) if defined(&__always_inline);
	eval 'sub __always_inline () { &__inline;}' unless defined(&__always_inline);
    }
    if( &__GNUC_PREREQ (4,3)) {
	eval 'sub __attribute_artificial__ () { &__attribute__ (( &__artificial__));}' unless defined(&__attribute_artificial__);
    } else {
	eval 'sub __attribute_artificial__ () {1;}' unless defined(&__attribute_artificial__);
    }
    if((!defined (&__cplusplus) ||  &__GNUC_PREREQ (4,3) || (defined (&__clang__)  && (defined (&__GNUC_STDC_INLINE__) || defined (&__GNUC_GNU_INLINE__))))) {
	if(defined (&__GNUC_STDC_INLINE__) || defined (&__cplusplus)) {
	    eval 'sub __extern_inline () { &extern  &__inline  &__attribute__ (( &__gnu_inline__));}' unless defined(&__extern_inline);
	    eval 'sub __extern_always_inline () { &extern  &__always_inline  &__attribute__ (( &__gnu_inline__));}' unless defined(&__extern_always_inline);
	} else {
	    eval 'sub __extern_inline () { &extern  &__inline;}' unless defined(&__extern_inline);
	    eval 'sub __extern_always_inline () { &extern  &__always_inline;}' unless defined(&__extern_always_inline);
	}
    }
    if(defined(&__extern_always_inline)) {
	eval 'sub __fortify_function () { &__extern_always_inline  &__attribute_artificial__;}' unless defined(&__fortify_function);
    }
    if( &__GNUC_PREREQ (4,3)) {
	eval 'sub __va_arg_pack () {
	    eval q( &__builtin_va_arg_pack ());
	}' unless defined(&__va_arg_pack);
	eval 'sub __va_arg_pack_len () {
	    eval q( &__builtin_va_arg_pack_len ());
	}' unless defined(&__va_arg_pack_len);
    }
    if(! &__GNUC_PREREQ (2,8)) {
	eval 'sub __extension__ () {1;}' unless defined(&__extension__);
    }
    if(! &__GNUC_PREREQ (2,92)) {
	eval 'sub __restrict () {1;}' unless defined(&__restrict);
    }
    if( &__GNUC_PREREQ (3,1)  && !defined (&__GNUG__)) {
	eval 'sub __restrict_arr () { &__restrict;}' unless defined(&__restrict_arr);
    } else {
	if(defined(&__GNUC__)) {
	    eval 'sub __restrict_arr () {1;}' unless defined(&__restrict_arr);
	} else {
	    if(defined (&__STDC_VERSION__)  && (defined(&__STDC_VERSION__) ? &__STDC_VERSION__ : undef) >= 199901) {
		eval 'sub __restrict_arr () { &restrict;}' unless defined(&__restrict_arr);
	    } else {
		eval 'sub __restrict_arr () {1;}' unless defined(&__restrict_arr);
	    }
	}
    }
    if((defined(&__GNUC__) ? &__GNUC__ : undef) >= 3) {
	eval 'sub __glibc_unlikely {
	    my($cond) = @_;
    	    eval q( &__builtin_expect (($cond), 0));
	}' unless defined(&__glibc_unlikely);
	eval 'sub __glibc_likely {
	    my($cond) = @_;
    	    eval q( &__builtin_expect (($cond), 1));
	}' unless defined(&__glibc_likely);
    } else {
	eval 'sub __glibc_unlikely {
	    my($cond) = @_;
    	    eval q(($cond));
	}' unless defined(&__glibc_unlikely);
	eval 'sub __glibc_likely {
	    my($cond) = @_;
    	    eval q(($cond));
	}' unless defined(&__glibc_likely);
    }
    if((!defined (&_Noreturn)  && (defined (&__STDC_VERSION__) ? (defined(&__STDC_VERSION__) ? &__STDC_VERSION__ : undef) : 0) < 201112 && ! &__GNUC_PREREQ (4,7))) {
	if( &__GNUC_PREREQ (2,8)) {
	    eval 'sub _Noreturn () { &__attribute__ (( &__noreturn__));}' unless defined(&_Noreturn);
	} else {
	    eval 'sub _Noreturn () {1;}' unless defined(&_Noreturn);
	}
    }
    if((!defined (&_Static_assert)  && !defined (&__cplusplus)  && (defined (&__STDC_VERSION__) ? (defined(&__STDC_VERSION__) ? &__STDC_VERSION__ : undef) : 0) < 201112 && (! &__GNUC_PREREQ (4, 6) || defined (&__STRICT_ANSI__)))) {
	eval 'sub _Static_assert {
	    my($expr, $diagnostic) = @_;
    	    eval q( &extern  &int (* &__Static_assert_function ( &void)) [!!$sizeof{\'struct struct\' { \'int\'  &__error_if_negative: ($expr) ? 2: -1; }}]);
	}' unless defined(&_Static_assert);
    }
    require 'bits/wordsize.ph';
    if(defined (&__LONG_DOUBLE_MATH_OPTIONAL)  && defined (&__NO_LONG_DOUBLE_MATH)) {
	eval 'sub __LDBL_COMPAT () {1;}' unless defined(&__LDBL_COMPAT);
	if(defined(&__REDIRECT)) {
	    eval 'sub __LDBL_REDIR1 {
	        my($name, $proto, $alias) = @_;
    		eval q( &__REDIRECT ($name, $proto, $alias));
	    }' unless defined(&__LDBL_REDIR1);
	    eval 'sub __LDBL_REDIR {
	        my($name, $proto) = @_;
    		eval q( &__LDBL_REDIR1 ($name, $proto,  &__nldbl_$name));
	    }' unless defined(&__LDBL_REDIR);
	    eval 'sub __LDBL_REDIR1_NTH {
	        my($name, $proto, $alias) = @_;
    		eval q( &__REDIRECT_NTH ($name, $proto, $alias));
	    }' unless defined(&__LDBL_REDIR1_NTH);
	    eval 'sub __LDBL_REDIR_NTH {
	        my($name, $proto) = @_;
    		eval q( &__LDBL_REDIR1_NTH ($name, $proto,  &__nldbl_$name));
	    }' unless defined(&__LDBL_REDIR_NTH);
	    eval 'sub __LDBL_REDIR1_DECL {
	        my($name, $alias) = @_;
    		eval q( &extern  &__typeof ($name) $name  &__asm ( &__ASMNAME ($alias)););
	    }' unless defined(&__LDBL_REDIR1_DECL);
	    eval 'sub __LDBL_REDIR_DECL {
	        my($name) = @_;
    		eval q( &extern  &__typeof ($name) $name  &__asm ( &__ASMNAME (\\"__nldbl_\\" $name)););
	    }' unless defined(&__LDBL_REDIR_DECL);
	    eval 'sub __REDIRECT_LDBL {
	        my($name, $proto, $alias) = @_;
    		eval q( &__LDBL_REDIR1 ($name, $proto,  &__nldbl_$alias));
	    }' unless defined(&__REDIRECT_LDBL);
	    eval 'sub __REDIRECT_NTH_LDBL {
	        my($name, $proto, $alias) = @_;
    		eval q( &__LDBL_REDIR1_NTH ($name, $proto,  &__nldbl_$alias));
	    }' unless defined(&__REDIRECT_NTH_LDBL);
	}
    }
    if(!defined (&__LDBL_COMPAT) || !defined (&__REDIRECT)) {
	eval 'sub __LDBL_REDIR1 {
	    my($name, $proto, $alias) = @_;
    	    eval q($name $proto);
	}' unless defined(&__LDBL_REDIR1);
	eval 'sub __LDBL_REDIR {
	    my($name, $proto) = @_;
    	    eval q($name $proto);
	}' unless defined(&__LDBL_REDIR);
	eval 'sub __LDBL_REDIR1_NTH {
	    my($name, $proto, $alias) = @_;
    	    eval q($name $proto  &__THROW);
	}' unless defined(&__LDBL_REDIR1_NTH);
	eval 'sub __LDBL_REDIR_NTH {
	    my($name, $proto) = @_;
    	    eval q($name $proto  &__THROW);
	}' unless defined(&__LDBL_REDIR_NTH);
	eval 'sub __LDBL_REDIR_DECL {
	    my($name) = @_;
    	    eval q();
	}' unless defined(&__LDBL_REDIR_DECL);
	if(defined(&__REDIRECT)) {
	    eval 'sub __REDIRECT_LDBL {
	        my($name, $proto, $alias) = @_;
    		eval q( &__REDIRECT ($name, $proto, $alias));
	    }' unless defined(&__REDIRECT_LDBL);
	    eval 'sub __REDIRECT_NTH_LDBL {
	        my($name, $proto, $alias) = @_;
    		eval q( &__REDIRECT_NTH ($name, $proto, $alias));
	    }' unless defined(&__REDIRECT_NTH_LDBL);
	}
    }
}
1;
