FROM rhel_7-base
MAINTAINER David Laube <dlaube@packet.net>
LABEL Description="Packet's rhel 7.3 OS image" Vendor="Packet.net"

# Register system with redhat, temporarily
RUN subscription-manager register \
	--username $SMUSER \
	--password $SMPASS \
	--auto-attach \
	--force

# Downgrade to 7.3 per https://red.ht/2nYdvlz
RUN yum -y downgrade redhat-release

# Remove RHN registration
RUN rm -f /etc/sysconfig/rhn/systemid
