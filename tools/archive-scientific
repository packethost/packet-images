#!/bin/bash

# ./script ./image.tar.gz ./mytars

IMAGE=$1
OUTDIR=$2

#IMAGETMP=$(mktemp -d -t image-XXXXXXX)
IMAGETMP=image-temp
mkdir -p $IMAGETMP
tar -zxf $IMAGE -C $IMAGETMP

KERNEL=$(ls -al $IMAGETMP/boot/vmlinuz-* | awk {'print $9'} | sort -V | grep -v rescue | head -1)
INITRD=$(ls -al $IMAGETMP/boot/initramfs* | awk {'print $9'} | sort -V | grep -v rescue | head -1)
KERNELVER=$(echo $KERNEL | sed "s/$IMAGETMP\/boot\/vmlinuz-//g")

echo "Kernel file: $KERNEL"
echo "Initrd file: $INITRD"
echo "Kernel version: $KERNELVER"

tmp=$(mktemp -d -t initrd4me-XXXXXXX)
mkdir $tmp/boot
mkdir -p $OUTDIR
# shellcheck disable=SC2064
trap "rm -rf $tmp; rm -rf $IMAGETMP" EXIT
echo "Temp directory is: $tmp"
echo "Archive dir is: $OUTDIR"

echo "Archiving kernel..."
cp $KERNEL $tmp/boot
mv $tmp/boot/vmlinuz-$KERNELVER $tmp/boot/vmlinuz
tar -czf $OUTDIR/kernel.tar.gz -C $tmp/boot ./vmlinuz --totals --checkpoint=.1000

echo "Archiving initrd..."
cp $INITRD $tmp/boot
mv $tmp/boot/initramfs-$KERNELVER.img $tmp/boot/initrd
tar -czf $OUTDIR/initrd.tar.gz -C $tmp/boot ./initrd --totals --checkpoint=.1000

echo "Archiving modules..."
tar -czf $OUTDIR/modules.tar.gz $IMAGETMP/lib/modules/$KERNELVER --totals --checkpoint=.1000

rm -rf $IMAGETMP
