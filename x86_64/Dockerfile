FROM debian:stretch
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's Debian stretch OS base image" Vendor="Packet.net" Version="1.0"

# Setup the environment
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get -q update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq install \
		apt-transport-https \
		bash \
		bash-completion \
		bc \
		ca-certificates \
		cloud-init \
		cron \
		curl \
		dbus \
		dialog \
		dstat \
		ethstatus \
		file \
		fio \
		haveged \
		htop \
		ifenslave \
		ioping \
		initramfs-tools \
		iotop \
		iperf \
		iptables \
		iputils-ping \
		jq \
		less \
		libmlx5-1 \
		locales \
		locate \
		lsb-release \
		lsof \
		make \
		man-db \
		mdadm \
		mg \
		mosh \
		mtr \
		multipath-tools \
		nano \
		net-tools \
		netcat \
		nmap \
		ntp \
		ntpdate \
		open-iscsi \
		python-apt \
		python-yaml \
		rsync \
		rsyslog \
		screen \
		shunit2 \
		socat \
		software-properties-common \
		ssh \
		sudo \
		sysstat \
		systemd-sysv \
		tar \
		tcpdump \
		tmux \
		traceroute \
		unattended-upgrades \
		uuid-runtime \
		vim \
		wget

# Install a specific kernel
RUN apt-get -q update && \
    apt-get -y -qq install \
    linux-image-4.9.0-5-amd6 \
    && apt-get -y remove --purge linux-image-4.9.0-5-amd64-dbg

# Assign default target
RUN systemctl set-default multi-user

# Enable update-motd.d support
RUN rm -f /etc/motd && ln -s /var/run/motd /etc/motd

# Configure locale
RUN echo "Etc/UTC" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

# Configure Systemd
RUN systemctl disable \
	systemd-modules-load.service \
	systemd-update-utmp-runlevel \
	proc-sys-fs-binfmt_misc.automount \
	kmod-static-nodes.service

# Replace init with systemd
RUN rm -f /sbin/init \
	&& ln -sf ../lib/systemd/systemd /sbin/init

# Fix perms
RUN chmod 755 /etc/default

# Clean APT cache
RUN apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/*

# vim: set tabstop=4 shiftwidth=4:
