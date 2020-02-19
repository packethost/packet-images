#!/bin/sh
#
# This script does the required startup checks before the iSCSI
# daemon should be started. It also generates a name if that
# hadn't been done before.
#

PATH=/sbin:/bin

NAMEFILE=/etc/iscsi/initiatorname.iscsi
CONFIGFILE=/etc/iscsi/iscsid.conf

if [ ! -e "$CONFIGFILE" ]; then
	echo >&2
	echo "Error: configuration file $CONFIGFILE is missing!" >&2
	echo "The iSCSI driver has not been correctly installed and cannot start." >&2
	echo >&2
	exit 1
fi

if [ ! -f $NAMEFILE ]; then
	echo >&2
	echo "Error: InitiatorName file $NAMEFILE is missing!" >&2
	echo "The iSCSI driver has not been correctly installed and cannot start." >&2
	echo >&2
	exit 1
fi

# see if we need to generate a unique iSCSI InitiatorName
if grep -q "^GenerateName=yes" $NAMEFILE ; then
	if [ ! -x /sbin/iscsi-iname ] ; then
		echo "Error: /sbin/iscsi-iname does not exist, driver was not successfully installed" >&2
		exit 1
	fi
	# Generate a unique InitiatorName and save it
	INAME=`/sbin/iscsi-iname -p iqn.1993-08.org.debian:01`
	if [ "$INAME" != "" ] ; then
		echo "## DO NOT EDIT OR REMOVE THIS FILE!" > $NAMEFILE
		echo "## If you remove this file, the iSCSI daemon will not start." >> $NAMEFILE
		echo "## If you change the InitiatorName, existing access control lists" >> $NAMEFILE
		echo "## may reject this initiator.  The InitiatorName must be unique">> $NAMEFILE
		echo "## for each iSCSI initiator.  Do NOT duplicate iSCSI InitiatorNames." >> $NAMEFILE
		printf "InitiatorName=$INAME\n"  >> $NAMEFILE
		chmod 600 $NAMEFILE
	else
		echo "Error: failed to generate an iSCSI InitiatorName, driver cannot start." >&2
		echo >&2
		exit 1
	fi
fi

# make sure there is a valid InitiatorName for the driver
if ! grep -q "^InitiatorName=[^ \t\n]" $NAMEFILE ; then
	echo >&2
	echo "Error: $NAMEFILE does not contain a valid InitiatorName." >&2
	echo "The iSCSI driver has not been correctly installed and cannot start." >&2
	echo >&2
	exit 1
fi
