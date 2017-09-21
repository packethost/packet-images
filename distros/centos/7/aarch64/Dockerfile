FROM project31/aarch64-centos:7
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's CentOS 7 OS base image" Vendor="Packet.net"
LABEL Version="2017.04.13.00"

ADD qemu-aarch64-static /usr/bin/qemu-aarch64-static

# Replace systemd so everything else actually works
RUN yum clean all && yum swap -y systemd-container-libs systemd-libs

RUN yum update  ${YUM_OPTS} -y && \
	yum install ${YUM_OPTS} -y \
	bash \
	bash-completion \
	ca-certificates \
	cloud-init \
	curl \
	device-mapper-multipath \
	dosfstools \
	e2fsprogs \
	iscsi-initiator-utils \
	libselinux-python \
	make \
	mdadm \
	mtr \
	net-tools \
	NetworkManager-team \
	NetworkManager-tui \
	nmap-ncat \
	ntp \
	ntpdate \
	openssh-clients \
	openssh-server \
	policycoreutils-python \
	python-configobj \
	python-jsonpointer \
	python-requests \
	PyYAML \
	redhat-lsb-core \
	rsync \
	screen \
	socat \
	sudo \
	sysstat \
	tar \
	tcpdump \
	teamd \
	tmux \
	traceroute \
	vim \
	wget \
	&& yum clean all

RUN systemctl enable cloud-init
RUN yum -y reinstall cracklib-dicts

RUN rm /usr/bin/qemu-aarch64-static
# vim: set tabstop=4 shiftwidth=4:
