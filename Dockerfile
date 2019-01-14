FROM centos_7-base
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's centos_7-baremetal_2a6 OS image" Vendor="Packet.net"

## HW specific image modifications go in this file

# Update packages
RUN yum -y update

# Install a specific kernel and deps
RUN yum -y install kernel-4.14.0-115.2.2.el7a linux-firmware

# Adjust generic initrd
RUN dracut --filesystems="ext4 vfat" --mdadmconf --force /boot/initramfs-4.14.0-115.2.2.el7a.aarch64.img 4.14.0-115.2.2.el7a.aarch64

# Clean yum cache
RUN yum clean all
