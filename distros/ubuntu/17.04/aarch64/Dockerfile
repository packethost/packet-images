FROM scratch
ADD rootfs.tar.gz /
ADD qemu-aarch64-static /usr/bin/qemu-aarch64-static

ARG BUILDDATE
RUN if [ -z "$BUILDDATE" ]; then \
		echo "empty build arg: BUILDDATE"; \
		exit 1; \
	else \
		printf "BUILDDATE=$BUILDDATE\nDESCRIPTION='Packet Ubuntu 17.04 x86_64 base image'\n" >/etc/packet-build-info; \
	fi

# Setup the environment
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get -q update && \
	apt-get -y -qq upgrade && \
	apt-get install -y -qq \
		bash \
		bash-completion \
		bc \
		ca-certificates \
		cloud-init \
		cron \
		curl \
		dbus \
		dstat \
		ethstatus \
		file \
		fio \
		htop \
		ifenslave \
		ioping \
		iotop \
		iperf \
		iptables \
		iputils-ping \
		less \
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
		tar \
		tcpdump \
		tmux \
		traceroute \
		unattended-upgrades \
		uuid-runtime \
		vim \
		wget \
		locales \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/*

# Configure locales
RUN locale-gen en_US.UTF-8 \
	&& dpkg-reconfigure locales

# Fix permissions
RUN chown root:syslog /var/log \
	&& chmod 755 /etc/default

# Fix cloud-init EC2 warning
RUN touch /root/.cloud-warnings.skip

RUN rm /usr/bin/qemu-aarch64-static
# vim: set tabstop=4 shiftwidth=4:
