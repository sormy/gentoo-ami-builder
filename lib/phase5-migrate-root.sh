#!/bin/bash

################################################################################

# %ELIB% - this line indicates that ELIB should be injected below

################################################################################

PRI_DISK_DEV=$(find_disk1)
PRI_ROOT_DEV=$(blkid | grep 'LABEL="/"' | sed 's/:.*$//')
PRI_ESP_DEV=$(blkid | grep 'PARTLABEL="EFI' | sed 's/:.*$//')
AUX_ROOT_DEV=$(blkid | grep 'LABEL="aux-root"' | sed 's/:.*$//')

################################################################################

# in debug mode partitions could be still mounted by previous failed attempt
if mount | grep -q /mnt/gentoo; then
    einfo "Unmounting partitions..."

    # if chroot is not needed, then this unmount is not needed as well
    eqexec umount /mnt/gentoo/dev/shm
    eqexec umount /mnt/gentoo/dev/pts
    eqexec umount /mnt/gentoo/dev
    eqexec umount /mnt/gentoo/sys
    eqexec umount /mnt/gentoo/proc

    if [ -n "$PRI_ESP_DEV" ]; then
        eqexec umount /mnt/gentoo/boot/efi
    fi

    eexec umount /mnt/gentoo
fi

################################################################################

einfo "Migrating root partition from aux to primary disk..."

eindent

einfo "Copying root partition..."

# TODO: make RO mount work
# eexec mount -o remount,ro /
eexec sync
eexec dd "if=$AUX_ROOT_DEV" "of=$PRI_ROOT_DEV" bs=1M
eexec sync
# eexec mount -o remount,rw /

einfo "Fixing root partition identity..."

eexec tune2fs -U random "$PRI_ROOT_DEV"
eexec e2label "$PRI_ROOT_DEV" /

eoutdent

################################################################################

einfo "Mounting primary disk..."

eindent

einfo "Mounting root..."
eexec mkdir -p /mnt/gentoo
eexec mount "$PRI_ROOT_DEV" /mnt/gentoo

if [ -n "$PRI_ESP_DEV" ]; then
    einfo "Mounting ESP..."
    eexec mkdir -p /mnt/gentoo/boot/efi
    eexec mount "$PRI_ESP_DEV" /mnt/gentoo/boot/efi
fi

# if chroot is not needed, then this mount is not needed as well
einfo "Mounting proc/sys/dev..."
eexec mount -t proc none /mnt/gentoo/proc
eexec mount -o bind /sys /mnt/gentoo/sys
eexec mount -o bind /dev /mnt/gentoo/dev
eexec mount -o bind /dev/pts /mnt/gentoo/dev/pts
eexec mount -o bind /dev/shm /mnt/gentoo/dev/shm

eoutdent

################################################################################

einfo "Cleaning primary disk..."

# clear ec2 init state if available
eqexec rm "/mnt/gentoo/var/lib/ec2-init.lock"
eqexec rm "/mnt/gentoo/var/lib/ec2-init.user-data"
eqexec rm "/mnt/gentoo/var/log/ec2-init.log"

# clear ssh authorized keys
eqexec rm "/mnt/gentoo/root/.ssh/authorized_keys"

# reset hostname
if [ -e "/mnt/gentoo/etc/conf.d/hostname" ]; then
    echo "hostname=localhost" > "/mnt/gentoo/etc/conf.d/hostname"
fi

################################################################################

einfo "Fixing boot on primary disk..."

eindent

if [ -n "$PRI_ESP_DEV" ]; then
    einfo "Installing bootloader into ESP..."
    # TODO: try without chroot
    # eexec grub-install --root-directory=/mnt/gentoo \
    #    --efi-directory=/mnt/gentoo/boot/efi --removable
    eexec chroot /mnt/gentoo grub-install --efi-directory=/boot/efi --removable
else
    einfo "Installing bootloader into MBR..."
    # TODO: try without chroot
    # eexec grub-install "$PRI_DISK_DEV" --root-directory=/mnt/gentoo
    eexec chroot /mnt/gentoo grub-install "$PRI_DISK_DEV"
fi

einfo "Configuring bootloader..."
# TODO: try without chroot
# eexec GRUB_DEVICE="$PRI_DISK_DEV" grub-mkconfig -o /mnt/gentoo/boot/grub/grub.cfg
eexec chroot /mnt/gentoo grub-mkconfig -o /boot/grub/grub.cfg

if [ -n "$PRI_ESP_DEV" ]; then
    einfo "Cleaning ESP..."
    eqexec rm -rf /mnt/gentoo/boot/efi/EFI/amzn
fi

einfo "Fixing fstab..."
eexec sed -i -e 's!^LABEL=aux-root!LABEL=/!' /mnt/gentoo/etc/fstab

eoutdent
