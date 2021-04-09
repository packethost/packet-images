newns () {
  [ "$OS_PROBER_NEWNS" ] || exec /usr/lib/os-prober/newns "$0" "$@"
}

cleanup_tmpdir=false
cleanup_ro_partitions=
cleanup () {
  local partition
  for partition in $cleanup_ro_partitions; do
    blockdev --setrw "$partition"
  done
  if $cleanup_tmpdir; then
    rm -rf "$OS_PROBER_TMP"
  fi
}

require_tmpdir() {
  if [ -z "$OS_PROBER_TMP" ]; then
    if type mktemp >/dev/null 2>&1; then
      export OS_PROBER_TMP="$(mktemp -d /tmp/os-prober.XXXXXX)"
      cleanup_tmpdir=:
      trap cleanup EXIT HUP INT QUIT TERM
    else
      export OS_PROBER_TMP=/tmp
    fi
  fi
}

count_for() {
  _labelprefix="$1"
  _result=$(grep "^${_labelprefix} " /var/lib/os-prober/labels 2>/dev/null || true)

  if [ -z "$_result" ]; then
    return
  else
    echo "$_result" | cut -d' ' -f2
  fi
}

count_next_label() {
  require_tmpdir

  _labelprefix="$1"
  _cfor="$(count_for "${_labelprefix}")"

  if [ -z "$_cfor" ]; then
    echo "${_labelprefix} 1" >> /var/lib/os-prober/labels
  else
    sed "s/^${_labelprefix} ${_cfor}/${_labelprefix} $(($_cfor + 1))/" /var/lib/os-prober/labels > "$OS_PROBER_TMP/os-prober.tmp"
    mv "$OS_PROBER_TMP/os-prober.tmp" /var/lib/os-prober/labels
  fi
  
  echo "${_labelprefix}${_cfor}"
}

progname=
cache_progname() {
  case $progname in
    '')
      progname="$(basename "$0")"
      ;;
  esac
}

log() {
  cache_progname
  logger -t "$progname" "$@"
}

error() {
  log "error: $@"
}

warn() {
  log "warning: $@"
}

debug() {
  log "debug: $@"
}

result () {
  log "result:" "$@"
  echo "$@"
}

# shim to make it easier to use os-prober outside d-i
if ! type mapdevfs >/dev/null 2>&1; then
  mapdevfs () {
    readlink -f "$1"
  }
fi

item_in_dir () {
	if [ "$1" = "-q" ]; then
		q="-q"
		shift 1
	else
		q=""
	fi
	[ -d "$2" ] || return 1
	# find files with any case
	ls -1 "$2" | grep $q -i "^$1$"
}

# We can't always tell the filesystem type up front, but if we have the
# information then we should use it. Note that we can't use block-attr here
# as it's only available in udebs.
# If not detected after different attempts then "NOT-DETECTED" will be printed
# because function is not supposed to exit error codes.
fs_type () {
	local fstype=""
	if (export PATH="/lib/udev:$PATH"; type vol_id) >/dev/null 2>&1; then
		PATH="/lib/udev:$PATH" \
			fstype=$(vol_id --type "$1" 2>/dev/null || true)
		[ -z "$fstype" ] || { echo "$fstype"; return; }
	fi
	if type lsblk >/dev/null 2>&1 ; then
		fstype=$(lsblk --nodeps --noheading --output FSTYPE -- "$1" || true)
		[ -z "$fstype" ] || { echo "$fstype"; return; }
	fi
	if type blkid >/dev/null 2>&1; then
		fstype=$(blkid -o value -s TYPE "$1" 2>/dev/null || true)
		[ -z "$fstype" ] || { echo "$fstype"; return; }
	fi
	echo "NOT-DETECTED"
}

is_dos_extended_partition() {
	if type blkid >/dev/null 2>&1; then
		local output

		output="$(blkid -o export $1)"

		# old blkid (util-linux << 2.24) errors out on extended p.
		if [ "$?" = "2" ]; then
			return 0
		fi

		# dos partition type and no filesystem type?...
		if echo $output | grep -q ' PTTYPE=dos ' &&
				! echo $output | grep -q ' TYPE='; then
			return 0
		else
			return 1
		fi
	fi

	return 1
}

parse_proc_mounts () {
	while read -r line; do
		set -f
		set -- $line
		set +f
		printf '%s %s %s\n' "$(mapdevfs "$1")" "$2" "$3"
	done
}

parsefstab () {
	while read -r line; do
		case "$line" in
			"#"*)
				:	
			;;
			*)
				set -f
				set -- $line
				set +f
				printf '%s %s %s\n' "$1" "$2" "$3"
			;;
		esac
	done
}

unescape_mount () {
	printf %s "$1" | \
		sed 's/\\011/	/g; s/\\012/\n/g; s/\\040/ /g; s/\\134/\\/g'
}

ro_partition () {
	if type blockdev >/dev/null 2>&1 && \
	   [ "$(blockdev --getro "$1")" = 0 ] && \
	   blockdev --setro "$1"; then
		cleanup_ro_partitions="${cleanup_ro_partitions:+$cleanup_ro_partitions }$1"
		trap cleanup EXIT HUP INT QUIT TERM
	fi
}

find_label () {
	local output
	if type blkid >/dev/null 2>&1; then
		# Hopefully everyone has blkid by now
		output="$(blkid -o device -t LABEL="$1")" || return 1
		echo "$output" | head -n1
	elif [ -h "/dev/disk/by-label/$1" ]; then
		# Last-ditch fallback
		readlink -f "/dev/disk/by-label/$1"
	else
		return 1
	fi
}

find_uuid () {
	local output
	if type blkid >/dev/null 2>&1; then
		# Hopefully everyone has blkid by now
		output="$(blkid -o device -t UUID="$1")" || return 1
		echo "$output" | head -n1
	elif [ -h "/dev/disk/by-uuid/$1" ]; then
		# Last-ditch fallback
		readlink -f "/dev/disk/by-uuid/$1"
	else
		return 1
	fi
}

# Sets $mountboot as output variable.  (We do this rather than requiring a
# subshell so that we can run ro_partition without the cleanup trap firing
# when the subshell exits.)
linux_mount_boot () {
	partition="$1"
	tmpmnt="$2"

	bootpart=""
	mounted=""
	if [ -e "$tmpmnt/etc/fstab" ]; then
		# Try to mount any /boot partition.
		bootmnt=$(parsefstab < "$tmpmnt/etc/fstab" | grep " /boot ") || true
		if [ -n "$bootmnt" ]; then
			set -f
			set -- $bootmnt
			set +f
			boottomnt=""

			# Try to map labels and UUIDs ourselves if possible,
			# so that we can check whether they're already
			# mounted somewhere else.
			tmppart="$1"
			if echo "$1" | grep -q "LABEL="; then
				label="$(echo "$1" | cut -d = -f 2)"
				if tmppart="$(find_label "$label")"; then
					debug "mapped LABEL=$label to $tmppart"
				else
					debug "found boot partition LABEL=$label for Linux system on $partition, but cannot map to existing device"
					mountboot="$partition 0"
					return
				fi
			elif echo "$1" | grep -q "UUID="; then
				uuid="$(echo "$1" | cut -d = -f 2)"
				if tmppart="$(find_uuid "$uuid")"; then
					debug "mapped UUID=$uuid to $tmppart"
				else
					debug "found boot partition UUID=$uuid for Linux system on $partition, but cannot map to existing device"
					mountboot="$partition 0"
					return
				fi
			fi
			shift
			set -- "$(mapdevfs "$tmppart")" "$@"

			if grep -q "^$1 " "$OS_PROBER_TMP/mounted-map"; then
				bindfrom="$(grep "^$1 " "$OS_PROBER_TMP/mounted-map" | head -n1 | cut -d " " -f 2)"
				bindfrom="$(unescape_mount "$bindfrom")"
				if [ "$bindfrom" != "$tmpmnt/boot" ]; then
					if mount --bind "$bindfrom" "$tmpmnt/boot"; then
						mounted=1
						bootpart="$1"
					else
						debug "failed to bind-mount $bindfrom onto $tmpmnt/boot"
					fi
				fi
			fi
			if [ "$mounted" ]; then
				:
			elif [ -e "$1" ]; then
				bootpart="$1"
				boottomnt="$1"
			elif [ -e "$tmpmnt/$1" ]; then
				bootpart="$1"
				boottomnt="$tmpmnt/$1"
			elif [ -e "/target/$1" ]; then
				bootpart="$1"
				boottomnt="/target/$1"
			else
				bootpart=""
			fi

			if [ ! "$mounted" ]; then
				if [ -z "$bootpart" ]; then
					debug "found boot partition $1 for linux system on $partition, but cannot map to existing device"
				else
					debug "found boot partition $bootpart for linux system on $partition"
					if type grub-mount >/dev/null 2>&1 && \
					   grub-mount "$boottomnt" "$tmpmnt/boot" 2>/dev/null; then
						mounted=1
					else
						ro_partition "$boottomnt"
						if mount -o ro "$boottomnt" "$tmpmnt/boot" -t "$3"; then
							mounted=1
						else
							error "failed to mount $boottomnt on $tmpmnt/boot"
						fi
					fi
				fi
			fi
		fi
	fi
	if [ -z "$bootpart" ]; then
		bootpart="$partition"
	fi
	if [ -z "$mounted" ]; then
		mounted=0
	fi

	mountboot="$bootpart $mounted"
}
