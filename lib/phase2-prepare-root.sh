#!/bin/bash

################################################################################

# %ELIB% - this line indicates that ELIB should be injected below

################################################################################

# global WGET_OPTS
# global GENTOO_DISTFILES_URL
# global GENTOO_ARCH
# global GENTOO_PROFILE

################################################################################

# in debug mode partitions could be still mounted by previous failed attempt
DISK1=$(find_disk1)
DISK2=$(find_disk2)
DISK1P1=$(append_disk_part $DISK1 1)
DISK2P1=$(append_disk_part $DISK2 1)

################################################################################

einfo "Setting time..."

# having wrong time will cause all kinds of troubles
eexec yum -y -q install ntp
eexec ntpd -gq

################################################################################

# in debug mode the same phase could be executed multiple times leaving
# partitions mounted if previous phase did not explicitly unmount them
if mount | grep -q /mnt/gentoo; then
    einfo "Unmounting partitions..."

    qexec umount /mnt/gentoo/dev/pts
    qexec umount /mnt/gentoo/dev
    qexec umount /mnt/gentoo/sys
    qexec umount /mnt/gentoo/proc

    eexec umount /mnt/gentoo
fi

################################################################################

einfo "Preparing disk 2..."

eindent

einfo "Creating partitions..."

echo ";" | qexec sfdisk --label dos "$DISK2"
while [ ! -e $DISK2P1 ]; do sleep 1; done

einfo "Formatting partitions..."

eexec mkfs.ext4 -q $DISK2P1

einfo "Labeling partitions..."

eexec e2label $DISK2P1 aux-root

eoutdent

################################################################################

einfo "Mounting disk 2..."

eexec mkdir -p /mnt/gentoo
eexec mount $DISK2P1 /mnt/gentoo

################################################################################

einfo "Setting work directory..."

eexec cd /mnt/gentoo

################################################################################

einfo "Installing stage3..."

eindent

einfo "Downloading..."

STAGE3_PATH_URL="$GENTOO_DISTFILES_URL/releases/$GENTOO_ARCH/autobuilds/latest-stage3-$GENTOO_PROFILE.txt"
STAGE3_PATH="$(curl -s "$STAGE3_PATH_URL" | grep -v "^#" | cut -d" " -f1)"
STAGE3_URL="$GENTOO_DISTFILES_URL/releases/$GENTOO_ARCH/autobuilds/$STAGE3_PATH"

eexec wget $WGET_OPTS "$STAGE3_URL"

einfo "Extracting..."

eexec tar xpf "$(basename "$STAGE3_URL")" --xattrs-include='*.*' --numeric-owner

einfo "Cleaning up..."

eexec rm stage3-*

eoutdent

################################################################################

einfo "Installing portage repo..."

eindent

einfo "Initializing..."

eexec mkdir -p /mnt/gentoo/etc/portage/repos.conf
eexec cp -f /mnt/gentoo/usr/share/portage/config/repos.conf \
    /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

einfo "Downloading..."

PORTAGE_URL="$GENTOO_DISTFILES_URL/snapshots/portage-latest.tar.xz"
eexec wget $WGET_OPTS "$PORTAGE_URL"

einfo "Extracting..."

eexec tar xf "$(basename "$PORTAGE_URL")" -C usr --xattrs-include='*.*' --numeric-owner

einfo "Cleaning up..."

eexec rm portage-*

eoutdent

################################################################################

einfo "Installing local overlay (with ENA)..."

create_local_overlay_with_ena_module /mnt/gentoo

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

einfo "Mounting proc/sys/dev/pts..."

eexec mount -t proc none /mnt/gentoo/proc
eexec mount -o bind /sys /mnt/gentoo/sys
eexec mount -o bind /dev /mnt/gentoo/dev
eexec mount -o bind /dev/pts /mnt/gentoo/dev/pts

################################################################################
