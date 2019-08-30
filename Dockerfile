FROM debian_9-base
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's debian_9-baremetal_2a4 OS image" Vendor="Packet.net"

## HW specific image modifications go in this file

# Set up the environment
ENV DEBIAN_FRONTEND=noninteractive

# Update packages
RUN apt-get -q update \
	&& apt-get -y -qq upgrade

# Install a specific kernel
RUN apt-get -y -qq install \
	linux-image-4.9.0-9-arm64 \
	grub-efi-arm64

# Install QLogic NIC firmware
RUN add-apt-repository non-free \
	&& apt-get -q update \
	&& apt-get -y -qq install firmware-qlogic

# Clean APT cache
RUN apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/*
