FROM ubuntu_18_04-base
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's ubuntu_18_04-g2.large.x86 OS image" Vendor="Packet.net"

## HW specific image modifications go in this file

RUN add-apt-repository ppa:graphics-drivers/ppa -y && apt update
RUN apt dist-upgrade -y
RUN apt install -y linux-firmware nvidia-driver-415 linux-image-generic linux-headers-generic
