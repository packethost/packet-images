TARGETS = mountkernfs.sh hostname.sh screen-cleanup udev mountdevsubfs.sh procps urandom hwclock.sh iscsid networking open-iscsi checkroot.sh checkroot-bootclean.sh bootmisc.sh kmod mountnfs.sh multipath-tools-boot checkfs.sh mountall.sh mountall-bootclean.sh mountnfs-bootclean.sh
INTERACTIVE = udev checkroot.sh checkfs.sh
udev: mountkernfs.sh
mountdevsubfs.sh: mountkernfs.sh udev
procps: mountkernfs.sh udev
urandom: hwclock.sh
hwclock.sh: mountdevsubfs.sh
iscsid: networking
networking: mountkernfs.sh urandom procps
open-iscsi: networking iscsid
checkroot.sh: hwclock.sh mountdevsubfs.sh hostname.sh
checkroot-bootclean.sh: checkroot.sh
bootmisc.sh: checkroot-bootclean.sh mountall-bootclean.sh udev mountnfs-bootclean.sh
kmod: checkroot.sh
mountnfs.sh: networking
multipath-tools-boot: checkroot.sh udev
checkfs.sh: multipath-tools-boot checkroot.sh
mountall.sh: multipath-tools-boot checkfs.sh checkroot-bootclean.sh
mountall-bootclean.sh: mountall.sh
mountnfs-bootclean.sh: mountnfs.sh
