#!/bin/sh
#
# This script activates storage at boot after the iSCSI login. It can
# be called from both the init script as well as the native systemd
# service.
#

PATH=/sbin:/bin

MULTIPATH=/sbin/multipath
VGCHANGE=/sbin/vgchange

if [ -f /etc/default/open-iscsi ]; then
	. /etc/default/open-iscsi
fi

# See if we need to handle LVM
if [ ! -x $VGCHANGE ] && [ -n "$LVMGROUPS" ]; then
	echo "Warning: LVM2 tools are not installed, not honouring LVMGROUPS." >&2
	LVMGROUPS=""
fi

# If we don't have to activate any VGs and are running systemd, we
# don't have to activate anything, so doing udevadm settle here and
# potentially sleeping (if multipath is used) will not be productive,
# because after waiting for both of these things, we will do nothing.
# Therefore just drop out early if that is the case.
if [ -d /run/systemd/system ] && [ -z "$LVMGROUPS" ] ; then
	exit 0
fi

# Make sure we pick up all devices
udevadm settle || true

# Work around race condition here: after udevadm settle it is
# guaranteed that all iSCSI disks have now properly appeared, but
# other dependent devices may not have. This can include multipath
# mappings of iSCSI devices (multipathd will race against udev for
# locking the underlying source block devices when it comes to
# creating the mappings, and it will retry the lock only once per
# second, and typically succeed only on second try), but also
# partitions on the given disks (which the kernel scans
# asyncronously).
#
# The proper way of handling this is to have LVM activation and/or
# mounting of file systems be handled in a completely event-driven
# manner, but that requires configuration by the sysadmin in the
# case of LVM, and for mounting it only works with systemd at the
# moment. For compatibility with how the package handled this
# previously, we will work around this race for a while longer.

if [ -x $MULTIPATH ] ; then
	# 1 second is too short for multipath devices to appear,
	# because multipathd takes more than 1s to activate them
	# after udevadm settle is done.
	sleep 3
else
	sleep 1
fi
udevadm settle || true

# Handle LVM
if [ -n "$LVMGROUPS" ] ; then
	if ! $VGCHANGE -ay $LVMGROUPS ; then
		echo "Warning: could not activate all LVM groups." >&2
	fi
	# Make sure we pick up all LVM devices
	udevadm settle || true
fi

# Mount all network filesystems
# (systemd takes care of it directly, so don't do it there)
if ! [ -d /run/systemd/system ] ; then
	if [ $HANDLE_NETDEV -eq 1 ] ; then
		mount -a -O _netdev >/dev/null 2>&1 || true
		# FIXME: should we really support swap on iSCSI?
		#        If so, we should update umountiscsi.sh!
		swapon -a -e >/dev/null 2>&1 || true
	fi
fi
