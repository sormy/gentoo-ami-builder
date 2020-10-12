#!/bin/bash

################################################################################

# %ELIB% - this line indicates that ELIB should be injected below

################################################################################

# global CURL_OPTS
# global GENTOO_MIRROR
# global GENTOO_ARCH
# global GENTOO_STAGE3

################################################################################

# in debug mode partitions could be still mounted by previous failed attempt
DISK1="$(find_disk1)"
DISK2="$(find_disk2)"
DISK1P1="$(append_disk_part "$DISK1" 1)"
DISK2P1="$(append_disk_part "$DISK2" 1)"

################################################################################

einfo "Synchronizing time..."

# having wrong time will cause all kinds of troubles
eexec yum -y -q install ntp
eexec ntpd -gq

################################################################################

# in debug mode the same phase could be executed multiple times leaving
# partitions mounted if previous phase did not explicitly unmount them
if mount | grep -q /mnt/gentoo; then
    einfo "Unmounting partitions..."

    eqexec umount /mnt/gentoo/dev/shm
    eqexec umount /mnt/gentoo/dev/pts
    eqexec umount /mnt/gentoo/dev
    eqexec umount /mnt/gentoo/sys
    eqexec umount /mnt/gentoo/proc

    eexec umount /mnt/gentoo
fi

################################################################################

einfo "Preparing disk 2..."

eindent

einfo "Creating partitions..."

echo ";" | eqexec sfdisk --label dos "$DISK2"
while [ ! -e "$DISK2P1" ]; do sleep 1; done

einfo "Formatting partitions..."

eexec mkfs.ext4 -q "$DISK2P1"

einfo "Labeling partitions..."

eexec e2label "$DISK2P1" aux-root

eoutdent

################################################################################

einfo "Mounting disk 2..."

eexec mkdir -p /mnt/gentoo
eexec mount "$DISK2P1" /mnt/gentoo

################################################################################

einfo "Setting work directory..."

eexec cd /mnt/gentoo

################################################################################

einfo "Installing stage3..."

eindent

STAGE3_PATH_URL="$GENTOO_MIRROR/releases/$GENTOO_ARCH/autobuilds/latest-stage3-$GENTOO_STAGE3.txt"
STAGE3_PATH="$(curl -s "$STAGE3_PATH_URL" | grep -v "^#" | cut -d" " -f1)"
STAGE3_URL="$GENTOO_MIRROR/releases/$GENTOO_ARCH/autobuilds/$STAGE3_PATH"
STAGE3_FILE="$(basename "$STAGE3_URL")"

einfo "Downloading: $STAGE3_URL ..."

download_distfile_safe "$STAGE3_URL" "$STAGE3_FILE"

einfo "Extracting..."

eexec tar xpf "$STAGE3_FILE" --xattrs-include='*.*' --numeric-owner

einfo "Cleaning up..."

eexec rm stage3-*

eoutdent

################################################################################

einfo "Installing Amazon's kernel configuration..."

eexec mkdir -p /mnt/gentoo/etc/kernels
eexec cp -f /boot/config-* /mnt/gentoo/etc/kernels

################################################################################

einfo "Configuring fstab..."

cat >> /mnt/gentoo/etc/fstab << END
LABEL=aux-root / ext4 noatime 0 1
END

################################################################################

einfo "Copying network options..."

eexec cp -f /etc/resolv.conf /mnt/gentoo/etc/

################################################################################

einfo "Mounting proc/sys/dev..."

eexec mount -t proc none /mnt/gentoo/proc
eexec mount -o bind /sys /mnt/gentoo/sys
eexec mount -o bind /dev /mnt/gentoo/dev
eexec mount -o bind /dev/pts /mnt/gentoo/dev/pts
eexec mount -o bind /dev/shm /mnt/gentoo/dev/shm

################################################################################
