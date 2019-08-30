FROM ubuntu_18_04-base
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's ubuntu_18_04-baremetal_2a4 OS image" Vendor="Packet.net"

## HW specific image modifications go in this file

# Set up the environment
ENV DEBIAN_FRONTEND=noninteractive
ENV FLASH_KERNEL_SKIP=1

# Install a specific kernel
RUN apt-get -q update \
	&& apt-get -y -qq upgrade \
	&& apt-get -y -qq install \
		linux-image-4.15.0-58-generic \
		linux-modules-4.15.0-58-generic \
		linux-modules-extra-4.15.0-58-generic \
		linux-headers-4.15.0-58-generic \
		linux-firmware \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/*
