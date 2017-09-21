FROM scratch
MAINTAINER David Laube <dlaube@packet.net>
ADD rootfs.tar.gz /

LABEL name="Ubuntu Canonical Base Image" \
    vendor="Ubuntu" \
    license="GPLv2" \
    build-date="20170508"


# Setup the environment
ENV DEBIAN_FRONTEND=noninteractive

# Enable universe repo for libmlx5
RUN sed -i '/^#\s*deb .* universe/ s|^#||' /etc/apt/sources.list

# Install packages
RUN apt-get -q update && \
	apt-get -y -qq dist-upgrade && \
	apt-get install -y -qq \
		bash \
		bash-completion \
		bc \
		biosdevname \
		ca-certificates \
		cloud-init \
		cron \
		curl \
		file \
		ifenslave \
		iptables \
		iputils-ping \
		less \
		libmlx5-1 \
		linux-image-3.13.0-123-generic \
		locales \
		lsb-release \
		lsof \
		make \
		man-db \
		mdadm \
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
		software-properties-common \
		ssh \
		sudo \
		sysstat \
		tar \
		tcpdump \
		tmux \
		unattended-upgrades \
		uuid-runtime \
		vim \
		wget \
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

# vim: set tabstop=4 shiftwidth=4:
