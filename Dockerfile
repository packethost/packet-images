FROM ubuntu_16_04-base
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's ubuntu_16_04-g2.large.x86 OS image" Vendor="Packet.net"

## HW specific image modifications go in this file

RUN add-apt-repository ppa:graphics-drivers/ppa -y && apt update
RUN apt dist-upgrade -y
RUN apt install -y linux-firmware nvidia-415 linux-image-generic linux-headers-generic
