FROM ubuntu_18_04-base
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's ubuntu_18_04-d1f.optane.x86 OS image" Vendor="Packet.net"

## HW specific image modifications go in this file

# Set up the environment
ENV DEBIAN_FRONTEND=noninteractive

# Install Intel microcode package
RUN apt-get -q update \
	&& apt-get -y -qq upgrade \
	&& apt-get -y -qq install \
		intel-microcode \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/*
