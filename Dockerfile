FROM opensuse_42_3-base
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's opensuse_42_3-baremetal_2a6 OS image" Vendor="Packet.net"

# Install a specific kernel and deps
RUN zypper install -y kernel-default-4.4.76-1.1.aarch64 kernel-firmware kmod

# Clean package cache
RUN zypper clean --all

# Adjust generic initrd
RUN dracut --filesystems="ext4 vfat" --mdadmconf --force initrd-4.4.76-1-default 4.4.76-1-default
