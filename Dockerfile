FROM centos_7-base
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's centos_7-c2.large.arm OS image" Vendor="Packet.net"

## HW specific image modifications go in this file

# Correct locale
RUN localedef -i en_US -f UTF-8 en_US.UTF-8

# Update packages
RUN yum -y update

# Install a specific kernel and deps
RUN yum -y install kernel-4.14.0-115.2.2.el7a linux-firmware

# Adjust generic initrd
RUN dracut -v --no-host-only --force /boot/initramfs-4.14.0-115.2.2.el7a.aarch64.img 4.14.0-115.2.2.el7a.aarch64

# Clean yum cache
RUN yum clean all
