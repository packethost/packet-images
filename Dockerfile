FROM ubuntu_16_04-base
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's ubuntu_16_04-d1p.optane.x86 OS image" Vendor="Packet.net"

## HW specific image modifications go in this file

# Set up the environment
ENV DEBIAN_FRONTEND=noninteractive

# Install a specific kernel
RUN apt-get -q update \
	&& apt-get -y -qq upgrade \
	&& apt-get -y -qq install \
		linux-image-4.15.0-33-generic \
		linux-modules-extra-4.15.0-33-generic \
		intel-microcode \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/*
