FROM multiarch/centos:7.2.1511-amd64-clean

ARG BUILDDATE
RUN if [ -z "$BUILDDATE" ]; then \
		echo "empty build arg: BUILDDATE"; \
		exit 1; \
	else \
		printf "BUILDDATE=$BUILDDATE\nDESCRIPTION='Packet Ubuntu 17.04 x86_64 base image'\n" >/etc/packet-build-info; \
	fi

RUN yum update  ${YUM_OPTS} -y && \
	yum install ${YUM_OPTS} -y \
	bash \
	bash-completion \
	ca-certificates \
	cloud-init \
	cron \
	curl \
	device-mapper-multipath \
	ethstatus \
	grub2 \
	ioping \
	iotop \
	iperf \
	iscsi-initiator-utils \
	locate \
	make \
	mdadm \
	mg \
	mtr \
	net-tools \
	NetworkManager-team \
	NetworkManager-tui \
	nmap-ncat \
	ntp \
	ntpdate \
	redhat-lsb-core \
	rsync \
	screen \
	socat \
	ssh \
	sudo \
	sysstat \
	systemd \
	tar \
	tcpdump \
	teamd \
	tmux \
	traceroute \
	vim \
	wget \
	&& yum clean all

# vim: set tabstop=4 shiftwidth=4:
