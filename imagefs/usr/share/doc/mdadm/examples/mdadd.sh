#!/bin/sh

MY_VERSION="1.52a"
# ----------------------------------------------------------------------------------------------------------------------
# Linux MD (Soft)RAID Add Script - Add a (new) harddisk to another multi MD-array harddisk
# Last update: January 10, 2012
# (C) Copyright 2005-2012 by Arno van Amersfoort
# Homepage              : http://rocky.eld.leidenuniv.nl/
# Email                 : a r n o v a AT r o c k y DOT e l d DOT l e i d e n u n i v DOT n l
#                         (note: you must remove all spaces and substitute the @ and the . at the proper locations!)
# ----------------------------------------------------------------------------------------------------------------------
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# ----------------------------------------------------------------------------------------------------------------------

EOL='
'

show_help()
{
  echo "Bad or missing parameter(s)"
  echo "Usage: $(basename $0) [ options ] [ source_disk ] [ target_disk ]"
  echo "Options:"
  echo "--force       = Even proceed if target device does not appear empty"
  echo "--noptupdate  = Do NOT update the partition table on the target device (EXPERT!)"
  echo "--nombrupdate = Do NOT update the MBR boot-loader on the target device (EXPERT!)"
}


get_partitions()
{
  local DEVICE="$(echo "$1" |sed s,'^/dev/',, )"

  if [ -z "$DEVICE" ]; then
    cat /proc/partitions |sed -e '1,2d' -e s,' /dev/',,
  else
    cat /proc/partitions |sed -e '1,2d' -e s,' /dev/',, |grep -E " ${DEVICE}p?[0-9]+$"
  fi
}

get_part_size()
{
  get_partitions |grep -E " ${1}$" |awk '{ print $3 }' 
}

check_binary()
{
  if ! which "$1" >/dev/null 2>&1; then
    printf "\033[40m\033[1;31mERROR: Binary \"$1\" does not exist or is not executable!\033[0m\n" >&2
    printf "\033[40m\033[1;31m       Please, make sure that it is (properly) installed!\033[0m\n" >&2
    exit 2
  fi
}


sanity_check()
{
  if [ "$(id -u)" != "0" ]; then 
    printf "\033[40m\033[1;31mERROR: Root check FAILED (you MUST be root to use this script)! Quitting...\n\033[0m" >&2
    exit 1
  fi

  check_binary mdadm
  check_binary sfdisk
  check_binary dd
  check_binary awk
  check_binary grep
  check_binary sed
  check_binary cat

  if [ -z "$SOURCE" ] || [ -z "$TARGET" ]; then
    echo "ERROR: Bad or missing argument(s)" >&2
    show_help;
    exit 4
  fi

  if ! echo "$SOURCE" |grep -q '^/dev/'; then
    printf "\033[40m\033[1;31mERROR: Source device $SOURCE does not start with /dev/! Quitting...\n\033[0m" >&2
    exit 5
  fi

  if ! echo "$TARGET" |grep -q '^/dev/'; then
    printf "\033[40m\033[1;31mERROR: Target device $TARGET does not start with /dev/! Quitting...\n\033[0m" >&2
    exit 5
  fi

  if echo "$SOURCE" |grep -q 'md[0-9]'; then
    printf "\033[40m\033[1;31mERROR: The source device specified is an md-device! Quitting...\n\033[0m" >&2
    echo "A physical drive (part of the md-array(s)) is required as source device (eg. /dev/sda)!" >&2
    exit 5
  fi

  # We also want variables without /dev/ :
  SOURCE_NODEV="$(echo "$SOURCE" |sed 's,^/dev/,,')"
  TARGET_NODEV="$(echo "$TARGET" |sed 's,^/dev/,,')"

  if [ -z "$(get_partitions ${SOURCE_NODEV})" ]; then
    printf "\033[40m\033[1;31mERROR: Source device $SOURCE does not contain any partitions!? Quitting...\n\033[0m" >&2
    exit 7
  fi

  if [ -n "$(get_partitions ${TARGET_NODEV})" ] && [ $FORCE -ne 1 ]; then
    sfdisk -l "$TARGET"
    printf "\033[40m\033[1;31mERROR: Target device $TARGET already contains partitions! Use --force to override. Quitting...\n\033[0m" >&2
    exit 8
  fi

  SOURCE_SIZE="$(get_part_size $SOURCE_NODEV)"
  TARGET_SIZE="$(get_part_size $TARGET_NODEV)"
  if [ $SOURCE_SIZE -gt $TARGET_SIZE ]; then
    printf "\033[40m\033[1;31mWARNING: Target device $TARGET ($TARGET_SIZE blocks) is smaller than source device $SOURCE ($SOURCE_SIZE blocks)\nPress enter to continue or CTRL-C to abort...\n\033[0m" >&2
    read
  fi

  echo "--> Saving mdadm detail scan to /tmp/mdadm-detail-scan..."
  mdadm --detail --scan --verbose >|/tmp/mdadm-detail-scan
  retval=$?
  if [ $retval -ne 0 ]; then
    printf "\033[40m\033[1;31mERROR: mdadm returned an error($retval) while determining detail information!\n\033[0m" >&2
    exit 9
  fi 

  echo "--> Saving partition table of target device $TARGET to /tmp/partitions.target..."
  sfdisk -d "$TARGET" >|"/tmp/partitions.target" 2>/dev/null
  retval=$?
  if [ $retval -ne 0 ]; then
    echo "NOTE: sfdisk returned an error($retval) while reading the partition table on $TARGET"
  fi

  echo "--> Saving partition table of source device $SOURCE to /tmp/partitions.source..."
  sfdisk -d "$SOURCE" >|"/tmp/partitions.source"
  retval=$?
  if [ $retval -ne 0 ]; then
    printf "\033[40m\033[1;31mERROR: sfdisk returned an error($retval) while reading the partition table on $SOURCE!\n\033[0m" >&2
    exit 11
  fi
  
  echo "--> Checking status of running MDs..."
  MD_DEV=""
  IFS=$EOL
  for MDSTAT_LINE in `cat /proc/mdstat`; do
    if echo "$MDSTAT_LINE" |grep -q '^md'; then
      MD_DEV_LINE="$MDSTAT_LINE"
      MD_DEV="$(echo "$MDSTAT_LINE" |awk '{ print $1 }')"

      IFS=$EOL
      for part_nodev in `cat "/tmp/partitions.target" |grep '^/dev/' |grep -i -v 'Id= 0' |awk '{ print $1 }' |sed 's,^/dev/,,'`; do
        if echo "$MD_DEV_LINE" |grep -E -q "[[:blank:]]$part_nodev\["; then
          printf "\033[40m\033[1;31mERROR: Partition /dev/$part_nodev on target device is already in use by array /dev/$MD_DEV!\n\033[0m" >&2
          exit 12
        fi
      done
    fi

    if echo "$MDSTAT_LINE" |grep -E -q '[[:blank:]]blocks[[:blank:]]' && ! echo "$MDSTAT_LINE" |grep -q '_'; then
      # This array is NOT degraded so now check whether we want to add devices to it:

      IFS=$EOL
      for part_nodev in `cat "/tmp/partitions.source" |grep '^/dev/' |grep -i -v 'Id= 0' |awk '{ print $1 }' |sed 's,^/dev/,,'`; do
        if echo "$MD_DEV_LINE" |grep -E -q "[[:blank:]]$part_nodev\["; then
          printf "$MD_DEV_LINE\n$MDSTAT_LINE\n"
          printf "\033[40m\033[1;31mWARNING: Array $MD_DEV is NOT degraded, target device ${TARGET}$(echo "$part_nodev" |sed "s,$SOURCE_NODEV,,") will become a hotspare!\nPress enter to continue or CTRL-C to abort...\n\033[0m" >&2
          read
        fi
      done
    fi
  done
}


# Wrapper for partprobe (call when performing a partition table update with eg. fdisk/sfdisk).
# $1 = Device to re-read
partprobe()
{
  local DEVICE="$1"
  local result=""
   
  printf "(Re)reading partition table on $DEVICE"
 
  # Retry several times since some daemons can block the re-reread for a while (like dm/lvm or blkid)
  for x in `seq 1 10`; do
    printf "."
    result=`sfdisk -R "$DEVICE" 2>&1`
    
    # Wait a bit for things to settle
    sleep 1

    if [ -z "$result" ]; then
      break;
    fi
  done
  
  echo ""
  
  if [ -n "$result" ]; then
    echo "$result" >&2
    return 1
  fi
  return 0
}


# Program entry point
echo "MDadd for SoftRAID-MDADM v$MY_VERSION"
echo "Written by Arno van Amersfoort"
echo "--------------------------------"

# Set environment variables to default
FORCE=0
NOPTUPDATE=0
NOMBRUPDATE=0
SOURCE=""
TARGET=""

# Check arguments
unset IFS
for arg in $*; do
  ARGNAME="$(echo "$arg" |cut -d= -f1)"
  ARGVAL="$(echo "$arg" |cut -d= -f2)"

  if ! echo "$ARGNAME" |grep -q '^-'; then
    if [ -z "$SOURCE" ]; then
      SOURCE="$ARGVAL"
    else
      if [ -z "$TARGET" ]; then
        TARGET="$ARGVAL"
      else
        show_help;
        exit 3
      fi
    fi
  else
    case "$ARGNAME" in
      --force|-force|-f) FORCE=1;;
      --noptupdate|-noptupdate|--noptu|-noptu) NOPTUPDATE=1;;
      --nombrupdate|-nombrupdate|--nombru|nombru) NOMBRUPDATE=1;;
      --help) show_help;
              exit 0;;
      *) echo "ERROR: Bad argument: $ARGNAME";
         show_help;
         exit 3;;
    esac
  fi
done

# Make sure everything is sane:
sanity_check;

# Disable all swaps on target disk
echo "--> Disabling any swap partitions on target device $TARGET"
IFS=$EOL
for SWAP in `grep -E "^${TARGET}p?[0-9]+" /proc/swaps |awk '{ print $1 }'`; do
  swapoff $SWAP >/dev/null 2>&1
done

# Update track0 on target disk
if [ $NOMBRUPDATE -ne 1 ]; then
  echo "--> Copying track0(containing MBR) from $SOURCE to $TARGET..."
  dd if="$SOURCE" of="$TARGET" bs=32768 count=1
  retval=$?
  if [ $retval -ne 0 ]; then
    printf "\033[40m\033[1;31mERROR: dd returned an error($retval) while copying track0!\n\033[0m" >&2
    exit 9
  fi
fi

PT_FILE="/tmp/partitions.source"
if [ $NOPTUPDATE -eq 1 ]; then
  PT_FILE="/tmp/partitions.target"
fi
  
echo "--> Restoring partition table from $PT_FILE to $TARGET..."
sfdisk --no-reread --force "$TARGET" < "$PT_FILE"
retval=$?
if [ $retval -ne 0 ]; then
  printf "\033[40m\033[1;31mERROR: sfdisk returned an error($retval) while writing the partition table!\n\033[0m" >&2
  exit 9
fi

echo ""

if [ $NOPTUPDATE -ne 1 ]; then
  # Re-read partition table
  partprobe "$TARGET"
  retval=$?
  if [ $retval -ne 0 ]; then
    printf "\033[40m\033[1;31mERROR: (Re)reading the partition table failed($retval)!\n\033[0m" >&2
    exit 9
  fi
fi

# Copy/build all md devices that exist on the source drive:
BOOT=0
NO_ADD=1
IFS=$EOL
for LINE in `cat /tmp/mdadm-detail-scan`; do
  if echo "$LINE" |grep -E -q '^ARRAY[[:blank:]]'; then
    MD_DEV=$(echo "$LINE" |awk '{ print $2 }')
  fi

  if echo "$LINE" |grep -E -q "devices=.*${SOURCE}p?[0-9]+"; then
    PARTITION_NR=""
    IFS=','
    for item in `echo "$LINE" |sed -e "s:.*devices=::"`; do
      if echo "$item" |grep -E -q -x "${SOURCE}p?[0-9]+"; then
        PARTITION_NR=`echo "$item" |sed s:"$SOURCE"::`
        break;
      fi
    done

    if [ -z "$PARTITION_NR" ]; then
      printf "\033[40m\033[1;31mERROR: Unable to retrieve detail information for $SOURCE from $MD_DEV!\n\033[0m" >&2
      exit 11
    fi

    # Check whether we're a root or boot partition
    if grep -E -q -e "^$MD_DEV[[:blank:]]*/boot[[:blank:]]" -e "$MD_DEV[[:blank:]]*/[[:blank:]]" /etc/fstab; then
      BOOT=1
    fi

    NO_ADD=0
    echo ""
    echo "--> Adding ${TARGET}${PARTITION_NR} to RAID array $MD_DEV:"
    printf "\033[40m\033[1;31m"
    mdadm --add "$MD_DEV" "${TARGET}${PARTITION_NR}"
    retval=$?
    if [ $retval -ne 0 ]; then
      printf "\033[40m\033[1;31mERROR: mdadm returned an error($retval) while adding device!\n\033[0m" >&2
      exit 12
    fi
    printf "\033[0m"
  fi
done

echo ""

# Create swapspace on partitions with ID=82
echo "--> Creating swapspace on target device (if any swap partitions exist)..."
IFS=$EOL
for SWAP_DEVICE in `sfdisk -d "$TARGET" 2>/dev/null |grep -i 'Id=82$' |awk '{ print $1 }'`; do
  if ! mkswap "$SWAP_DEVICE"; then
    printf "\033[40m\033[1;31mWARNING: mkswap failed for $SWAP_DEVICE\n\033[0m" >&2
  else
    swapon "$SWAP_DEVICE"
  fi

  if ! grep -E -q "^$SWAP_DEVICE[[:blank:]]*none[[:blank:]]*swap[[:blank:]]" /etc/fstab; then
    printf "\033[40m\033[1;31mWARNING: /etc/fstab does NOT contain a (valid) swap entry for $SWAP_DEVICE\n\033[0m" >&2
  fi
done

# Wait a bit for mdstat to settle
sleep 3

echo "--> Showing current /proc/mdstat (you may need to update your mdadm.conf (manually)..."
cat /proc/mdstat
echo ""

if [ $NO_ADD -eq 1 ]; then
  printf "\033[40m\033[1;31mWARNING: No mdadm --add actions were performed, please investigate!\n\033[0m" >&2
fi

if [ $BOOT -eq 1 ]; then
  printf "\033[40m\033[1;31mNOTE: Boot and/or root partition detected.\n      Please check your bootloader & active partitions!\n\033[0m"
fi
