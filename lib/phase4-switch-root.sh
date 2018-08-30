#!/bin/bash

################################################################################

# %ELIB% - this line indicates that ELIB should be injected below

################################################################################

# we need to detect disk device names and partition names
# as disk name could vary depending on instance type
DISK1="$(find_disk1)"
DISK2="$(find_disk2)"
DISK1P1="$(append_disk_part "$DISK1" 1)"
DISK2P1="$(append_disk_part "$DISK2" 1)"

# detect if target is systemd
GENTOO_SYSTEMD="$(
    (echo "$GENTOO_PROFILE" | grep -q 'systemd' \
        || echo "$GENTOO_STAGE3" | grep -q 'systemd') \
        && echo yes || echo no
)"

################################################################################

if ! mount | grep -q "/mnt/gentoo"; then
    einfo "Mounting partitions..."

    eexec mkdir -p /mnt/gentoo
    eexec mount "$DISK2P1" /mnt/gentoo
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

GRUB_CMDLINE_LINUX="net.ifnames=0"
if eon "$GENTOO_SYSTEMD"; then
    GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX init=/lib/systemd/systemd"
fi

for GRUB_CONFIG in $GRUB_CONFIG_SEARCH; do
    if [ -e "$GRUB_CONFIG" ]; then
        eexec sed -i \
            -e 's!/boot/\(vmlinuz\|kernel\)-\S\+!'"$KERNEL_FILE"'!g' \
            -e 's!/boot/initramfs-\S\+!'"$INITRAMFS_FILE"'!g' \
            -e 's!root=\S\+!root='"$ROOTFS_PART"' '"$GRUB_CMDLINE_LINUX"'!g' \
            "$GRUB_CONFIG"
    fi
done

################################################################################
