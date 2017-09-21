FROM centos/aarch64:7
ADD qemu-aarch64-static /usr/bin/qemu-aarch64-static

ARG BUILDDATE
RUN if [ -z "$BUILDDATE" ]; then \
		echo "empty build arg: BUILDDATE"; \
		exit 1; \
	else \
		printf "BUILDDATE=$BUILDDATE\nDESCRIPTION='Packet Ubuntu 17.04 x86_64 base image'\n" >/etc/packet-build-info; \
	fi

# !!!!!!!!!! README !!!!!!!!!!
#
# This build will likely fail on aufs/overlay storage drivers. It's been
# verified to work on zfs, btrfs may work also. The error shows up when using
# yum and manifests as corrupt rpmdb or checksums
#
# !!!!!!!!!! README !!!!!!!!!!

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
