cmd_arch/x86/purgatory/stack.o := gcc -Wp,-MD,arch/x86/purgatory/.stack.o.d  -nostdinc -isystem /usr/lib/gcc/x86_64-linux-gnu/5/include -I/usr/src/linux-headers-lbm- -I/build/linux-hwe-dLKN2F/linux-hwe-4.15.0/arch/x86/include -I./arch/x86/include/generated  -I/build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include -I./include -I/build/linux-hwe-dLKN2F/linux-hwe-4.15.0/arch/x86/include/uapi -I./arch/x86/include/generated/uapi -I/build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/uapi -I./include/generated/uapi -include /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/linux/kconfig.h -Iubuntu/include -I/build/linux-hwe-dLKN2F/linux-hwe-4.15.0/ubuntu/include -D__KERNEL__ -D__ASSEMBLY__ -fno-PIE -m64 -DCONFIG_X86_X32_ABI -DCONFIG_AS_CFI=1 -DCONFIG_AS_CFI_SIGNAL_FRAME=1 -DCONFIG_AS_CFI_SECTIONS=1 -DCONFIG_AS_FXSAVEQ=1 -DCONFIG_AS_SSSE3=1 -DCONFIG_AS_CRC32=1 -DCONFIG_AS_AVX=1 -DCONFIG_AS_AVX2=1 -DCONFIG_AS_AVX512=1 -DCONFIG_AS_SHA1_NI=1 -DCONFIG_AS_SHA256_NI=1 -DCC_HAVE_ASM_GOTO -mfentry -DCC_USING_FENTRY   -c -o arch/x86/purgatory/stack.o /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/arch/x86/purgatory/stack.S

source_arch/x86/purgatory/stack.o := /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/arch/x86/purgatory/stack.S

deps_arch/x86/purgatory/stack.o := \
  /build/linux-hwe-dLKN2F/linux-hwe-4.15.0/include/linux/compiler_types.h \
    $(wildcard include/config/have/arch/compiler/h.h) \
    $(wildcard include/config/enable/must/check.h) \
    $(wildcard include/config/enable/warn/deprecated.h) \

arch/x86/purgatory/stack.o: $(deps_arch/x86/purgatory/stack.o)

$(deps_arch/x86/purgatory/stack.o):
