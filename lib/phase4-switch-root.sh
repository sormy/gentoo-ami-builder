#!/bin/bash

################################################################################

# %ELIB% - this line indicates that ELIB should be injected below

################################################################################

# we need to detect disk device names and partition names
# as disk name could vary depending on instance type
DISK1=$(find_disk1)
DISK2=$(find_disk2)
DISK1P1=$(append_disk_part $DISK1 1)
DISK2P1=$(append_disk_part $DISK2 1)

################################################################################

if ! mount | grep -q "/mnt/gentoo"; then
    einfo "Mounting partitions..."

    eexec mkdir -p /mnt/gentoo
    eexec mount $DISK2P1 /mnt/gentoo
fi

################################################################################

einfo "Installing gentoo kernel on first disk..."

eexec cp -f /mnt/gentoo/boot/*-genkernel-* /boot/

################################################################################

einfo "Patching bootloader configuration on first disk..."

KERNEL_FILE=$(find /boot -type f -iname "kernel-genkernel-*" | head -n 1)
INITRAMFS_FILE=$(find /boot -type f -iname "initramfs-genkernel-*" | head -n 1)
ROOTFS_PART=$(blkid | grep aux-root | sed -e 's/^.* \(UUID=\S\+\).*$/\1/' -e 's/"//g')

[ -n "$KERNEL_FILE" ] || edie "Unable to find kernel file"
[ -n "$INITRAMFS_FILE" ] || edie "Unable to find initramfs file"
[ -n "$ROOTFS_PART" ] || edie "Unable to find rootfs partition"

GRUB_CONFIG_SEARCH="/boot/grub/menu.lst /boot/grub/grub.cfg /boot/grub2/grub.cfg"

for GRUB_CONFIG in $GRUB_CONFIG_SEARCH; do
    if [ -e "$GRUB_CONFIG" ]; then
        eexec sed -i \
            -e 's!/boot/\(vmlinuz\|kernel\)-\S\+!'$KERNEL_FILE'!g' \
            -e 's!/boot/initramfs-\S\+!'$INITRAMFS_FILE'!g' \
            -e 's!root=\S\+!root='$ROOTFS_PART'!g' \
            "$GRUB_CONFIG"
    fi
done

################################################################################
