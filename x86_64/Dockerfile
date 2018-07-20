FROM suse/sles12sp2:latest
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's SUSE SLES12 SP3 OS base image" Vendor="Packet.net" Version="1.0"
ARG REGCODE

# Temporarily register on CSP and set product to 12.3
RUN zypper --non-interactive install SUSEConnect
RUN SUSEConnect -p SLES/12.3/x86_64 -r $REGCODE

# Upgrade to 12.3 release since official 12.3 is not out yet (July-18)
RUN zypper --non-interactive install zypper-migration-plugin
RUN zypper migration --non-interactive --disable-repos --migration 2

# Enable the Public Cloud module to get cloud-init
RUN SUSEConnect -p sle-module-public-cloud/12/x86_64

# Upgrade distribution
RUN zypper --non-interactive dist-upgrade

# Install packages
RUN zypper --non-interactive install \
	audit \
	bash \
	bash-completion \
	ca-certificates \
	cloud-init \
	cron \
	curl \
	glibc-locale \
	iotop \
	keyutils \
	lsb-release \
	logrotate \
	make \
	mdadm \
	net-tools \
	netcat \
	nmap \
	ntp \
	mlocate \
	multipath-tools \
	openssh \
	openssl \
	open-iscsi \
	parted \
	pciutils \
	rsync \
	rsyslog \
	screen \
	socat \
	sudo \
	sysstat \
	systemd \
	tar \
	tcpdump \
	traceroute \
	tuned \
	vim \
	wget \
	vim

# Enable sshd and cloud-init services
RUN systemctl enable sshd cloud-config cloud-final cloud-init-local cloud-init

# Install a specific kernel and deps
RUN zypper install -y kernel-default-4.4.138-94.39.x86_64 kernel-firmware

# Clean package cache
RUN zypper clean --all

# Adjust generic initrd
RUN dracut --filesystems="ext4 vfat" --mdadmconf --force --no-host-only /boot/initrd-4.4.138-94.39-default 4.4.138-94.39-default

# Adjust root account
RUN passwd -d root && passwd -l root

# De-register and clean up
RUN SUSEConnect --de-register
RUN SUSEConnect --cleanup
