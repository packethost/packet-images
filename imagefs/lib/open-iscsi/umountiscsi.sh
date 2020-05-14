#!/bin/sh
#
# This script umounts mounted iSCSI devices on shutdown, if possible.
# It is supposed to catch most use cases but is not designed to work
# for every corner-case. It handles LVM and multipath, but only if
# one of the following stackings is used:
#   LVM -> multipath -> iSCSI
#   multipath -> iSCSI
#   LVM -> iSCSI
#   LVM -> LUKS -> multipath -> iSCSI
#   LVM -> LUKS -> iSCSI
#   LUKS -> LVM -> multipath -> iSCSI
#   LUKS -> multipath -> iSCSI
#   LUKS -> LVM -> iSCSI
#   LUKS -> iSCSI
# It does not try to umount anything belonging to any device that is
# also used as a backing store for the root filesystem. Any iSCSI
# device part of the backing store of the root filesystem will be noted
# in /run/open-iscsi/shutdown-keep-sessions, so that the session not be
# closed on shutdown.
#
# KNOWN ISSUES:
#    - It doesn't handle submounts properly in all corner cases.
#      Specifically, it doesn't handle a non-iSCSI mount below an
#      iSCSI mount if it isn't also marked _netdev in /etc/fstab.
#    - It does not handle other things device mapper can do, such as
#      RAID, crypto, manual mappings of parts of disks, etc.
#    - It doesn't try to kill programs still accessing those mounts,
#      umount will just fail then.
#    - It doesn't handle more complicated stackings such as overlayfs,
#      FUSE filesystems, loop devices, etc.
#    - It doesn't handle swap.
#
# LONG TERM GOAL:
#    - In the long term, there should be a solution where for each part
#      of the stacking (device mapper, LVM, overlayfs, etc.) explicit
#      depdendencies are declared with the init system such that it can
#      be automatically dismantled. That would make this script
#      superfluous and also not be a layering violation, as it
#      currently is.
#
# CODING CHOICES:
#    - On systems running sysvinit, this script might be called without
#      /usr being mounted, so a lot of very useful commands are not
#      available: head, tail, stat, awk, etc. This makes the script
#      quite ugly at places, but that can't be avoided.
#
# Author: Christian Seiler <christian@iwakd.de>
#

# Make sure we don't include /usr in our path, else future modifications
# to this script might accidentally use something from there and cause
# failure on separate-/usr sysvinit systems that isn't immediately
# noticed.
PATH=/sbin:/bin

EXCLUDE_MOUNTS_AT_SHUTDOWN=""
if [ -f /etc/default/open-iscsi ]; then
	. /etc/default/open-iscsi
fi

MULTIPATH=/sbin/multipath
PVS=/sbin/pvs
LVS=/sbin/lvs
VGS=/sbin/vgs
VGCHANGE=/sbin/vgchange
CRYPTSETUP=/sbin/cryptsetup
DMSETUP=/sbin/dmsetup

if [ -x $PVS ] && [ -x $LVS ] && [ -x $VGCHANGE ] ; then
	HAVE_LVM=1
else
	HAVE_LVM=0
fi
if [ -x $CRYPTSETUP ] && [ -x $DMSETUP ] ; then
	HAVE_LUKS=1
else
	HAVE_LUKS=0
fi

DRY_RUN=0

# We need to make sure that we don't try to umount the root device
# and for systemd systems, also /usr (which is pre-mounted in initrd
# there).
EXCLUDE_MOUNTS="/"
if [ -d /run/systemd/system ] ; then
        EXCLUDE_MOUNTS="$EXCLUDE_MOUNTS /usr"
fi
EXCLUDE_MOUNTS="${EXCLUDE_MOUNTS}${EXCLUDE_MOUNTS_AT_SHUTDOWN+ $EXCLUDE_MOUNTS_AT_SHUTDOWN}"
unset _EXCLUDE_MOUNTS

error_usage() {
	echo "Usage: $0 [--dry-run | --timeout secs]" >&2
	exit 1
}

timeout=0

if [ $# -gt 2 ] ; then
	error_usage
fi

if [ $# -eq 2 ] ; then
	if [ x"$1"x != x"--timeout"x ] ; then
		error_usage
	fi
	case "$2" in
		(-1)            timeout="$2" ;;
		(*[!0-9]*|"")   error_usage ;;
		(*)             timeout="$2" ;;
	esac
elif [ $# -eq 1 ] ; then
	if [ x"$1"x != x"--dry-run"x ] ; then
		error_usage
	fi
	DRY_RUN=1
fi

# poor man's hash implementation using shell variables
hash_keys() {
	_hash_keys_hash_key_prefix="${1}_"
	(
		IFS='='
		set | while read var value ; do
			if [ x"${var#$_hash_keys_hash_key_prefix}"x != x"${var}"x ] ; then
				printf '%s\n' "${var#$_hash_keys_hash_key_prefix}"
			fi
		done
	)
}


hash_clear() {
	for k in $(hash_keys "$1") ; do
		unset "${1}_${k}"
	done
}

hash_get() {
	_hash_get_var="$2_$(printf '%s' "$3" | sed 's%[^A-Za-z0-9_]%_%g')"
	eval _hash_get_value=\$${_hash_get_var}
	eval $1=\${_hash_get_value}
}

hash_set() {
	_hash_set_var="$1_$(printf '%s' "$2" | sed 's%[^A-Za-z0-9_]%_%g')"
	eval ${_hash_set_var}=\${3}
}

hash_unset() {
	_hash_set_var="$1_$(printf '%s' "$2" | sed 's%[^A-Za-z0-9_]%_%g')"
	unset ${_hash_set_var}
}

in_set() {
	eval _set=\$$1
	case "${_set}" in
		("$2"|*" $2"|"$2 "*|*" $2 "*) return 0 ;;
		(*)                           return 1 ;;
	esac
}

_add_to_set() {
	eval _set=\$$1
	case "${_set}" in
		("$2"|*" $2"|"$2 "*|*" $2 "*) ;;
		("")    _set="$2" ;;
		(*)     _set="${_set} $2" ;;
	esac
	eval $1=\${_set}
}

add_to_set() {
	_add_to_set_set="$1"
	shift
	for _add_to_set_val in "$@" ; do
		_add_to_set "${_add_to_set_set}" "${_add_to_set_val}"
	done
}

hash_add_to_set() {
	_hash_add_to_set_var="$1_$(printf '%s' "$2" | sed 's%[^A-Za-z0-9_]%_%g')"
	shift
	shift
	add_to_set "${_hash_add_to_set_var}" "$@"
}

device_majmin() {
	eval $1=\"\"
	_majmin_dec=$(LC_ALL=C ls -lnd /dev/"$2" | while read _perms _links _uid _gid _majcomma _min _rest ; do
		if [ x"${_majcomma%,}"x != x"${_majcomma}"x ] ; then
			printf '%s' ${_majcomma%,}:${_min}
		fi
		break
	done)
	[ -n "${_majmin_dec}" ] || return
	eval $1=\${_majmin_dec}
}

get_lvm_vgs() {
	# handle the case where we didn't get passed any PVs
	# at all
	[ $# -gt 0 ] || return 0
	# subshell for pwd change
	(
		cd /dev
		$PVS --noheadings -o vg_name "$@" 2>/dev/null
	)
}

enumerate_luks() {
	hash_clear LUKS_DEVICES_REVERSE_MAP

	_all_crypt_devices=$($DMSETUP info --noheadings -o name -c -S subsystem=CRYPT 2>/dev/null || :)
	for _crypt_device in ${_all_crypt_devices} ; do
		[ -b "/dev/mapper/${_crypt_device}" ] || continue
		_crypt_device="$(readlink -fe "/dev/mapper/${_crypt_device}" 2>/dev/null || :)"
		_crypt_device="${_crypt_device#/dev/}"
		[ -b "/dev/${_crypt_device}" ] || continue
		# dmsetup deps is weird, it outputs the following:
		# 1 dependencies : (XYZ)
		_dep=$($DMSETUP deps -o blkdevname "/dev/${_crypt_device}" | sed -n '1s%.*: (\(.*\)).*%\1%p')
		if [ -n "$_dep" ] && [ -b "/dev/${_dep}" ] ; then
			_dep="$(readlink -fe "/dev/$_dep" 2>/dev/null || :)"
			_dep="${_dep#/dev/}"
		fi
		if [ -n "$_dep" ] && [ -b "/dev/${_dep}" ] ; then
			hash_set LUKS_DEVICES_REVERSE_MAP "${_dep}" "${_crypt_device}"
		fi
	done
}

enumerate_iscsi_devices() {
	# Empty arrays
	iscsi_disks=""
	iscsi_partitions=""
	iscsi_multipath_disks=""
	iscsi_multipath_disk_aliases=""
	iscsi_multipath_partitions=""
	iscsi_lvm_vgs=""
	iscsi_lvm_lvs=""
	iscsi_potential_mount_sources=""
	iscsi_luks_pass1=""
	iscsi_luks_pass2=""

	hash_clear ISCSI_DEVICE_SESSIONS
	hash_clear ISCSI_MPALIAS_SESSIONS
	hash_clear ISCSI_LVMVG_SESSIONS
	hash_clear ISCSI_NUMDEVICE_SESSIONS
	ISCSI_EXCLUDED_SESSIONS=""

	# We first need to generate a global reverse mapping of all
	# cryptsetup (e.g. LUKS) devices, because there's no easy way
	# to query "is this the encrypted backing of an active crypto
	# mapping?
	enumerate_luks

	# Look for all iscsi disks
	for _host_dir in /sys/devices/platform/host* /sys/devices/pci*/*/*/host* ; do
		if ! [ -d "$_host_dir"/iscsi_host* ] || ! [ -d "$_host_dir"/iscsi_host/host* ] ; then
			continue
		fi
		for _session_dir in "$_host_dir"/session* ; do
			[ -d "$_session_dir"/target* ] || continue
			for _block_dev_dir in "$_session_dir"/target*/*\:*/block/* ; do
				_block_dev=${_block_dev_dir##*/}
				[ x"${_block_dev}"x != x"*"x ] || continue
				add_to_set iscsi_disks "${_block_dev}"
				hash_add_to_set ISCSI_DEVICE_SESSIONS "${_block_dev}" ${_session_dir}
			done
		done
	done

	# Look for all partitions on those disks
	for _disk in $iscsi_disks ; do
		hash_get _disk_sessions ISCSI_DEVICE_SESSIONS "${_disk}"
		for _part_dir in /sys/class/block/"${_disk}"/"${_disk}"?* ; do
			_part="${_part_dir##*/}"
			[ x"${_part}"x != x"${_disk}?*"x ] || continue
			add_to_set iscsi_partitions "${_part}"
			hash_set ISCSI_DEVICE_SESSIONS "${_part}" "${_disk_sessions}"
		done
	done

	if [ -x $MULTIPATH ] ; then
		# Look for all multipath disks
		for _disk in $iscsi_disks ; do
			hash_get _disk_sessions ISCSI_DEVICE_SESSIONS "${_disk}"
			for _alias in $($MULTIPATH -v1 -l /dev/"$_disk") ; do
				_mp_dev="$(readlink -fe "/dev/mapper/${_alias}" || :)"
				[ -n "${_mp_dev}" ] || continue
				add_to_set iscsi_multipath_disks "${_mp_dev#/dev/}"
				add_to_set iscsi_multipath_disk_aliases "${_alias}"
				hash_add_to_set ISCSI_DEVICE_SESSIONS "${_mp_dev#/dev/}" ${_disk_sessions}
				hash_add_to_set ISCSI_MPALIAS_SESSIONS "${_alias}" ${_disk_sessions}
			done
		done

		# Look for partitions on these multipath disks
		for _alias in $iscsi_multipath_disk_aliases ; do
			hash_get _mp_sessions ISCSI_MPALIAS_SESSIONS "${_alias}"
			for _part_name in /dev/mapper/"${_alias}"-part* ; do
				_part="$(readlink -fe "$_part_name" 2>/dev/null || :)"
				[ -n "${_part}" ] || continue
				add_to_set iscsi_multipath_partitions "${_part#/dev/}"
				hash_set ISCSI_DEVICE_SESSIONS "${_part#/dev/}" "${_mp_sessions}"
			done
		done
	fi

	if [ $HAVE_LUKS -eq 1 ] ; then
		# Look for all LUKS devices.
		for _dev in $iscsi_disks $iscsi_partitions $iscsi_multipath_disks $iscsi_multipath_partitions ; do
			hash_get _luksDev LUKS_DEVICES_REVERSE_MAP "${_dev}"
			[ -n "${_luksDev}" ] || continue
			add_to_set iscsi_luks_pass1 "${_luksDev}"
			hash_get _currentSession ISCSI_DEVICE_SESSIONS "${_dev}"
			if [ -n "${_currentSession}" ] ; then
				hash_set ISCSI_DEVICE_SESSIONS "${_luksDev}" "${_currentSession}"
			fi
		done
	fi

	if [ $HAVE_LVM -eq 1 ] ; then
		# Look for all LVM volume groups that have a backing store
		# on any iSCSI device we found. Also, add $LVMGROUPS set in
		# /etc/default/open-iscsi (for more complicated stacking
		# configurations we don't automatically detect).
		for _vg in $(get_lvm_vgs $iscsi_disks $iscsi_partitions $iscsi_multipath_disks $iscsi_multipath_partitions $iscsi_luks_pass1) $LVMGROUPS ; do
			add_to_set iscsi_lvm_vgs "$_vg"
		done

		# $iscsi_lvm_vgs is now unique list
		for _vg in $iscsi_lvm_vgs ; do
			# get PVs to track iSCSI sessions
			for _pv in $($VGS --noheadings -o pv_name "$_vg" 2>/dev/null) ; do
				_pv_dev="$(readlink -fe "$_pv" 2>/dev/null || :)"
				[ -n "${_pv_dev}" ] || continue
				hash_get _pv_sessions ISCSI_DEVICE_SESSIONS "${_pv_dev#/dev/}"
				hash_add_to_set ISCSI_LVMVG_SESSIONS "${_vg}" ${_pv_sessions}
			done

			# now we collected all sessions belonging to this VG
			hash_get _vg_sessions ISCSI_LVMVG_SESSIONS "${_vg}"

			# find all LVs
			for _lv in $($VGS --noheadings -o lv_name "$_vg" 2>/dev/null) ; do
				_dev="$(readlink -fe "/dev/${_vg}/${_lv}" 2>/dev/null || :)"
				[ -n "${_dev}" ] || continue
				iscsi_lvm_lvs="$iscsi_lvm_lvs ${_dev#/dev/}"
				hash_set ISCSI_DEVICE_SESSIONS "${_dev#/dev/}" "${_vg_sessions}"
			done
		done
	fi

	if [ $HAVE_LUKS -eq 1 ] ; then
		# Look for all LUKS devices.
		for _dev in $iscsi_lvm_lvs ; do
			hash_get _luksDev LUKS_DEVICES_REVERSE_MAP "${_dev}"
			[ -n "${_luksDev}" ] || continue
			add_to_set iscsi_luks_pass2 "${_luksDev}"
			hash_get _currentSession ISCSI_DEVICE_SESSIONS "${_dev}"
			if [ -n "${_currentSession}" ] ; then
				hash_set ISCSI_DEVICE_SESSIONS "${_luksDev}" "${_currentSession}"
			fi
		done
	fi

	# Gather together all mount sources
	iscsi_potential_mount_sources="$iscsi_potential_mount_sources $iscsi_disks $iscsi_partitions"
	iscsi_potential_mount_sources="$iscsi_potential_mount_sources $iscsi_multipath_disks $iscsi_multipath_partitions"
	iscsi_potential_mount_sources="$iscsi_potential_mount_sources $iscsi_lvm_lvs"
	iscsi_potential_mount_sources="$iscsi_potential_mount_sources $iscsi_luks_pass1 $iscsi_luks_pass2"

	# Convert them to numerical representation
	iscsi_potential_mount_sources_majmin=""
	for _src in $iscsi_potential_mount_sources ; do
		device_majmin _src_majmin "$_src"
		[ -n "$_src_majmin" ] || continue
		iscsi_potential_mount_sources_majmin="${iscsi_potential_mount_sources_majmin} ${_src_majmin}"
		hash_get _dev_sessions ISCSI_DEVICE_SESSIONS "${_src}"
		hash_set ISCSI_NUMDEVICE_SESSIONS "${_src_majmin}" "${_dev_sessions}"
	done

	# Enumerate mount points
	iscsi_mount_points=""
	iscsi_mount_point_ids=""
	while read _mpid _mppid _mpdev _mpdevpath _mppath _mpopts _other ; do
		if in_set iscsi_potential_mount_sources_majmin "$_mpdev" ; then
			if in_set EXCLUDE_MOUNTS "${_mppath}" ; then
				hash_get _dev_sessions ISCSI_NUMDEVICE_SESSIONS "${_mpdev}"
				add_to_set ISCSI_EXCLUDED_SESSIONS $_dev_sessions
				continue
			fi
			# list mountpoints in reverse order (in case
			# some are stacked) mount --move may cause the
			# order of /proc/self/mountinfo to not always
			# reflect the stacking order, so this is not
			# fool-proof, but it's better than nothing
			iscsi_mount_points="$_mppath $iscsi_mount_points"
			iscsi_mount_point_ids="$_mpid $iscsi_mount_points"
		fi
	done < /proc/self/mountinfo
}

try_umount() {
	# in order to handle stacking try twice; together with the fact
	# that the list of mount points is in reverse order of the
	# contents /proc/self/mountinfo this should catch most cases
	for retry in 1 2 ; do
		for path in $iscsi_mount_points ; do
			# first try to see if it really is a mountpoint
			# still (might be the second round this is done
			# and the mount is already gone, or something
			# else umounted it first)
			if ! fstab-decode mountpoint -q "$path" ; then
				continue
			fi

			# try to umount it
			if ! fstab-decode umount "$path" ; then
				# unfortunately, umount's exit code
				# may be a false negative, i.e. it
				# might give a failure exit code, even
				# though it succeeded, so check again
				if fstab-decode mountpoint -q "$path" ; then
					echo "Could not unmount $path" >&2
					any_umount_failed=1
				fi
			fi
		done
	done
}

try_deactivate_lvm() {
	[ $HAVE_LVM -eq 1 ] || return

	for vg in $iscsi_lvm_vgs ; do
		vg_excluded=0
		hash_get vg_sessions ISCSI_LVMVG_SESSIONS "$vg"
		for vg_session in $vg_sessions ; do
			if in_set ISCSI_EXCLUDED_SESSIONS "$vg_session" ; then
				vg_excluded=1
			fi
		done
		if [ $vg_excluded -eq 1 ] ; then
			# volume group on same iSCSI session as excluded
			# mount, don't disable it
			# (FIXME: we should only exclude VGs that contain
			# those mounts, not also those that happen to be
			# in the same iSCSI session)
			continue
		fi
		if ! $VGCHANGE --available=n $vg ; then
			# Make sure the volume group (still) exists. If
			# it doesn't we count that as deactivated, so
			# don't fail then.
			_vg_test=$(vgs -o vg_name --noheadings $vg 2>/dev/null || :)
			if [ -n "${_vg_test}" ] ; then
				echo "Cannot deactivate Volume Group $vg" >&2
				any_umount_failed=1
			fi
		fi
	done
}

try_dismantle_multipath() {
	[ -x $MULTIPATH ] || return

	for mpalias in $iscsi_multipath_disk_aliases ; do
		mp_excluded=0
		hash_get mp_sessions ISCSI_MPALIAS_SESSIONS "$mpalias"
		for mp_session in $mp_sessions ; do
			if in_set ISCSI_EXCLUDED_SESSIONS "$mp_session" ; then
				mp_excluded=1
			fi
		done
		if [ $mp_excluded -eq 1 ] ; then
			# multipath device on same iSCSI session as
			# excluded mount, don't disable it
			# (FIXME: we should only exclude multipath mounts
			# that contain those mounts, not also those that
			# happen to be in the same iSCSI session)
			continue
		fi
		if ! $MULTIPATH -f $mpalias ; then
			echo "Cannot dismantle Multipath Device $mpalias" >&2
			any_umount_failed=1
		fi
	done
}

try_dismantle_luks() {
	[ $HAVE_LUKS -eq 1 ] || return
	case "$1" in
	1)	iscsi_luks_current_pass="$iscsi_luks_pass1" ;;
	2|*)	iscsi_luks_current_pass="$iscsi_luks_pass2" ;;
	esac

	for luksDev in $iscsi_luks_current_pass ; do
		luks_excluded=0
		hash_get device_sessions ISCSI_DEVICE_SESSIONS "$luksDev"
		for device_session in $device_sessions ; do
			if in_set ISCSI_EXCLUDED_SESSIONS "$device_session" ; then
				luks_excluded=1
			fi
		done
		if [ $luks_excluded -eq 1 ] ; then
			continue
		fi
		_luksName="$($DMSETUP info -c --noheadings -o name /dev/"$luksDev" 2>/dev/null || :)"
		[ -n "${_luksName}" ] || continue
		if ! $CRYPTSETUP close "${_luksName}" ; then
			echo "Cannot dismantle cryptsetup device ${_luksName}" >&2
			any_umount_failed=1
		fi
	done
}

# Don't do this if we are using systemd as init system, since systemd
# takes care of network filesystems (including those marked _netdev) by
# itself.
if ! [ -d /run/systemd/system ] && [ $HANDLE_NETDEV -eq 1 ] && [ $DRY_RUN -eq 0 ]; then
	echo "Unmounting all devices marked _netdev";
	umount -a -O _netdev >/dev/null 2>&1
fi

enumerate_iscsi_devices

# Dry run? Just print what we want to do (useful for administrator to check).
if [ $DRY_RUN -eq 1 ] ; then
	echo "$0: would umount the following mount points:"
	had_mount=0
	if [ -n "$iscsi_mount_points" ] ; then
		for v in $iscsi_mount_points ; do
			echo "  $v"
			had_mount=1
		done
	fi
	[ $had_mount -eq 1 ] || echo "  (none)"

	echo "$0: would disable the following LUKS devices (second pass):"
	had_luks=0
	if [ -n "$iscsi_luks_pass2" ] ; then
		for v in ${iscsi_luks_pass2} ; do
			luks_excluded=0
			hash_get device_sessions ISCSI_DEVICE_SESSIONS "$v"
			for device_session in $device_sessions ; do
				if in_set ISCSI_EXCLUDED_SESSIONS "$device_session" ; then
					luks_excluded=1
				fi
			done
			if [ $luks_excluded -eq 1 ] ; then
				continue
			fi
			_luksName="$($DMSETUP info -c --noheadings -o name /dev/"$v" 2>/dev/null || :)"
			[ -n "${_luksName}" ] || continue
			echo "  ${_luksName}"
			had_luks=1
		done
	fi
	[ $had_luks -eq 1 ] || echo "  (none)"

	echo "$0: would deactivate the following LVM Volume Groups:"
	had_vg=0
	if [ -n "$iscsi_lvm_vgs" ] ; then
		for v in $iscsi_lvm_vgs ; do
			# sync this exclusion logic with try_deactivate_lvm
			vg_excluded=0
			hash_get vg_sessions ISCSI_LVMVG_SESSIONS "$v"
			for vg_session in $vg_sessions ; do
				if in_set ISCSI_EXCLUDED_SESSIONS "$vg_session" ; then
					vg_excluded=1
				fi
			done
			if [ $vg_excluded -eq 1 ] ; then
				continue
			fi
			echo "  $v"
			had_vg=1
		done
	fi
	[ $had_vg -eq 1 ] || echo "  (none)"

	echo "$0: would disable the following LUKS devices (first pass):"
	had_luks=0
	if [ -n "$iscsi_luks_pass1" ] ; then
		for v in ${iscsi_luks_pass1} ; do
			luks_excluded=0
			hash_get device_sessions ISCSI_DEVICE_SESSIONS "$v"
			for device_session in $device_sessions ; do
				if in_set ISCSI_EXCLUDED_SESSIONS "$device_session" ; then
					luks_excluded=1
				fi
			done
			if [ $luks_excluded -eq 1 ] ; then
				continue
			fi
			_luksName="$($DMSETUP info -c --noheadings -o name /dev/"$v" 2>/dev/null || :)"
			[ -n "${_luksName}" ] || continue
			echo "  ${_luksName}"
			had_luks=1
		done
	fi
	[ $had_luks -eq 1 ] || echo "  (none)"

	echo "$0: would deactivate the following multipath volumes:"
	had_mp=0
	if [ -n "$iscsi_multipath_disk_aliases" ] ; then
		for v in $iscsi_multipath_disk_aliases ; do
			# sync this exclusion logic with try_dismantle_multipath
			mp_excluded=0
			hash_get mp_sessions ISCSI_MPALIAS_SESSIONS "$v"
			for mp_session in $mp_sessions ; do
				if in_set ISCSI_EXCLUDED_SESSIONS "$mp_session" ; then
					mp_excluded=1
				fi
			done
			if [ $mp_excluded -eq 1 ] ; then
				continue
			fi
			echo "  $v"
			had_mp=1
		done
	fi
	[ $had_mp -eq 1 ] || echo "  (none)"

	if [ -n "$ISCSI_EXCLUDED_SESSIONS" ] ; then
		echo "$0: the following sessions are excluded from disconnection (because / or another excluded mount is on them):"
		for v in $ISCSI_EXCLUDED_SESSIONS ; do
			echo "  $v"
		done
	fi

	exit 0
fi

# after our first enumeration, write out a list of sessions that
# shouldn't be terminated because excluded mounts are on those
# sessions
if [ -n "$ISCSI_EXCLUDED_SESSIONS" ] ; then
	mkdir -p -m 0700 /run/open-iscsi
	for session in $ISCSI_EXCLUDED_SESSIONS ; do
		printf '%s\n' $session
	done > /run/open-iscsi/shutdown-keep-sessions
else
	# make sure there's no leftover from a previous call
	rm -f /run/open-iscsi/shutdown-keep-sessions
fi

any_umount_failed=0
try_umount
try_dismantle_luks 2
try_deactivate_lvm
try_dismantle_luks 1
try_dismantle_multipath

while [ $any_umount_failed -ne 0 ] && ( [ $timeout -gt 0 ] || [ $timeout -eq -1 ] ) ; do
	# wait a bit, perhaps there was still a program that
	# was terminating
	sleep 1

	# try again and decrease timeout
	enumerate_iscsi_devices
	any_umount_failed=0
	try_umount
	try_dismantle_luks 2
	try_deactivate_lvm
	try_dismantle_luks 1
	try_dismantle_multipath
	if [ $timeout -gt 0 ] ; then
		timeout=$((timeout - 1))
	fi
done

# Create signaling file (might be useful)
if [ $any_umount_failed -eq 1 ] ; then
	touch /run/open-iscsi/some_umount_failed
else
	rm -f /run/open-iscsi/some_umount_failed
fi
exit $any_umount_failed
