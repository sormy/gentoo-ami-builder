#!/bin/bash

################################################################################

# %ELIB% - this line indicates that ELIB should be injected below

################################################################################

# global EMERGE_OPTS
# global GENKERNEL_OPTS
# global GENTOO_ARCH
# global GENTOO_STAGE3
# global GENTOO_PROFILE
# global CURL_OPTS
# global GENTOO_UPDATE_WORLD
# global ROOT_PASSWORD

################################################################################

PRI_ESP_DEV=$(blkid | grep 'PARTLABEL="EFI' | sed 's/:.*$//')

# detect if target is systemd
GENTOO_SYSTEMD="$(
    (echo "$GENTOO_PROFILE" | grep -q 'systemd' \
        || echo "$GENTOO_STAGE3" | grep -q 'systemd') \
        && echo yes || echo no
)"

# detect kernel config file that should be used for bootstrap
KERNEL_CONFIG="$(find /etc/kernels -type f -name "config-*.amzn*" | head -n 1)"

# detect current Gentoo profile (from stage3)
CURRENT_PROFILE="$(readlink /etc/portage/make.profile | sed 's!^.*/profiles/!!')"

# https://www.gentoo.org/support/news-items/2019-06-05-amd64-17-1-profiles-are-now-stable.html
NO_SYMLINK_LIB_MIGRATION=no
if [ "$GENTOO_ARCH" = "amd64" ] \
    && ! echo "$CURRENT_PROFILE" | grep -q '17\.1' \
    && echo "$GENTOO_PROFILE" | grep -q '17\.1'
then
    NO_SYMLINK_LIB_MIGRATION=yes
fi

################################################################################

einfo "Updating configuration..."

eexec env-update
eexec source /etc/profile

################################################################################

einfo "Tuning compiler options..."

CPU_COUNT=$(cat /proc/cpuinfo | grep processor | wc -l)
MAKE_THREADS=$(expr $CPU_COUNT + 1)
MAKE_OPTS="-j$MAKE_THREADS"

cat >> /etc/portage/make.conf << END

# added by gentoo-ami-builder
CFLAGS="-O2 -pipe -mtune=generic"
CXXFLAGS="\$CFLAGS"
MAKEOPTS="$MAKE_OPTS"
END

################################################################################

einfo "Installing portage repo..."

eexec mkdir -p /etc/portage/repos.conf
eexec cp -f /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf
eexec emerge-webrsync

################################################################################

if [ -n "$GENTOO_PROFILE" ]; then
    if eon "$NO_SYMLINK_LIB_MIGRATION"; then
        einfo "Migrating current profile $CURRENT_PROFILE..."
        einfo "  see more: https://www.gentoo.org/support/news-items/2019-06-05-amd64-17-1-profiles-are-now-stable.html"

        eexec emerge -1 $EMERGE_OPTS "app-portage/unsymlink-lib"

        eexec unsymlink-lib --analyze
        eexec unsymlink-lib --migrate
        eexec unsymlink-lib --finish
    fi

    einfo "Switching profile to $GENTOO_PROFILE..."
    eexec eselect profile set "$GENTOO_PROFILE"

    if eon "$NO_SYMLINK_LIB_MIGRATION"; then
        # very slow, will trigger rebuild for gcc/glib
        einfo "Rebuilding packages referencing lib32..."
        eexec emerge -1 $EMERGE_OPTS /usr/lib/gcc /lib32 /usr/lib32
    fi
fi

################################################################################

if [ "$GENTOO_UPDATE_WORLD" != "no" ]; then
    einfo "Rebuilding the world..."

    # rebuild whole world with new compiler options, could be probably useful for x32
    if [ "$GENTOO_UPDATE_WORLD" = "rebuild" ]; then
        eexec emerge $EMERGE_OPTS -e @world
    elif [ "$GENTOO_UPDATE_WORLD" = "deep" ]; then
        eexec emerge $EMERGE_OPTS --update --newuse --deep --with-bdeps=y @world
    elif [ "$GENTOO_UPDATE_WORLD" = "fast" ]; then
        eexec emerge $EMERGE_OPTS --update --newuse @world
    fi

    eexec emerge $EMERGE_OPTS --depclean
fi

################################################################################

if [ -n "$PRI_ESP_DEV" ]; then
    einfo "Installing vfat support..."
    eexec emerge $EMERGE_OPTS "sys-fs/dosfstools"
fi

################################################################################

einfo "Tuning kernel configuration..."

eexec cp -f "$KERNEL_CONFIG" "$KERNEL_CONFIG.bootstrap"

# genkernel won't autoload module XEN/NVME BLKDEV, so we build them into kernel
# IXGBEVF: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sriov-networking.html
eexec sed -i \
    -e '/CONFIG_XEN_BLKDEV_FRONTEND[ =]/c\CONFIG_XEN_BLKDEV_FRONTEND=y' \
    -e '/CONFIG_NVME_CORE[ =]/c\CONFIG_NVME_CORE=y' \
    -e '/CONFIG_BLK_DEV_NVME[ =]/c\CONFIG_BLK_DEV_NVME=y' \
    -e '/CONFIG_IXGBEVF[ =]/c\CONFIG_IXGBEVF=y' \
    "$KERNEL_CONFIG.bootstrap"

if eon "$GENTOO_SYSTEMD"; then
    eexec sed -i \
        -e '/CONFIG_AUTOFS4_FS[ =]/c\CONFIG_AUTOFS4_FS=y' \
        -e '/CONFIG_CHECKPOINT_RESTORE[ =]/c\CONFIG_CHECKPOINT_RESTORE=y' \
        -e '/CONFIG_FANOTIFY[ =]/c\CONFIG_FANOTIFY=y' \
        -e '/CONFIG_CRYPTO_USER_API_HASH[ =]/c\CONFIG_CRYPTO_USER_API_HASH=y' \
        -e '/CONFIG_CGROUP_BPF[ =]/c\CONFIG_CGROUP_BPF=y' \
        "$KERNEL_CONFIG.bootstrap"
fi

if [ "$GENTOO_STAGE3" = "x32-openrc" ]; then
    eexec sed -i \
        -e '/CONFIG_X86_X32[ =]/c\CONFIG_X86_X32=y' \
        "$KERNEL_CONFIG.bootstrap"
fi

KERNEL_CONFIG="$KERNEL_CONFIG.bootstrap"

################################################################################

einfo "Installing kernel sources..."

# ena <= 2.6.1 is incompatible with fresh kernels, temporarily mask >=5.15 kernels
# mkdir -p /etc/portage/package.mask
# echo "# masked due to ena <= 2.6.1 being incompatible with kernels >= 5.15" > /etc/portage/package.mask/kernel
# echo ">=sys-kernel/gentoo-sources-5.15.0" >> /etc/portage/package.mask/kernel

eexec emerge $EMERGE_OPTS "sys-kernel/gentoo-sources"
eexec ln -sfnv "$(find /usr/src -maxdepth 1 -type d -iname 'linux-*' | head -n 1)" /usr/src/linux

einfo "Installing genkernel..."

# TODO: custom use flags probably make sense only for PC platform
echo "sys-kernel/genkernel -firmware" > /etc/portage/package.use/genkernel
echo "sys-apps/util-linux static-libs" >> /etc/portage/package.use/genkernel
eexec emerge $EMERGE_OPTS "sys-kernel/genkernel"

einfo "Installing kernel..."

eexec genkernel all $GENKERNEL_OPTS --makeopts="$MAKE_OPTS" --kernel-config="$KERNEL_CONFIG"

################################################################################

einfo "Installing ENA kernel module..."

eexec mkdir -p "/etc/portage/package.accept_keywords"

# full unmask with ** is used to workaround currently missing arm64 for KEYWORDS in ebuild
cat > "/etc/portage/package.accept_keywords/gentoo-ami-builder" << END
# added by gentoo-ami-builder
net-misc/ena-driver ~amd64 ~arm64
END

eexec emerge $EMERGE_OPTS "net-misc/ena-driver"

if eoff "$GENTOO_SYSTEMD"; then
    cat >> /etc/conf.d/modules << END

# added by gentoo-ami-builder
modules="ena"
END
else
    echo "ena" > /etc/modules-load.d/ena.conf
fi

eoutdent

################################################################################

einfo "Installing bootloader..."

GRUB_PLATFORMS=$([ -n "$PRI_ESP_DEV" ] && echo efi-64 || echo pc)

cat >> /etc/portage/make.conf << END

# added by gentoo-ami-builder
GRUB_PLATFORMS="$GRUB_PLATFORMS"
END

eexec emerge $EMERGE_OPTS "sys-boot/grub"

GRUB_CMDLINE_LINUX="net.ifnames=0"
if eon "$GENTOO_SYSTEMD"; then
    GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX init=/lib/systemd/systemd"
fi

cat >> /etc/default/grub << END

# added by gentoo-ami-builder
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX console=tty0 console=ttyS0,115200n8"
END

if eoff "$GENTOO_SYSTEMD"; then
    # enable serial console support after boot
    eexec sed -i -e 's/^#\(.* ttyS0 .*$\)/\1/' /etc/inittab

    # fixes non blocking error: `INIT: Id "f0" respawning too fast: disabled for 5 minutes`
    # cause: modern Gentoo has enabled serial for Raspberry Pi by default
    eexec sed -i -e 's/^f0:.*ttyAMA0/#\0/' /etc/inittab
fi

################################################################################

# Machine ID setup is mandatory for systemd to make it work properly.
if eon "$GENTOO_SYSTEMD"; then
    einfo "Configuring systemd..."

    eexec systemd-machine-id-setup
fi

################################################################################

einfo "Configuring network..."

if eoff "$GENTOO_SYSTEMD"; then
    eexec ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
    eexec rc-update add net.eth0 default
else
    cat > /etc/systemd/network/50-dhcp.network << END
[Match]
Name=*

[Network]
DHCP=yes
END
    eexec systemctl enable systemd-networkd

    eexec ln -snf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    eexec systemctl start systemd-resolved
fi

################################################################################

if eoff "$GENTOO_SYSTEMD"; then
    einfo "Installing DHCP support..."
    eexec emerge $EMERGE_OPTS net-misc/dhcpcd
fi

################################################################################

einfo "Configuring root password..."

if [ "$ROOT_PASSWORD" = "" ]; then
    eexec passwd -d -l root
else
    eexec sh -c 'echo "root:'"$ROOT_PASSWORD"'" | chpasswd'
fi

################################################################################

einfo "Configuring SSH..."

if eoff "$GENTOO_SYSTEMD"; then
    eexec rc-update add sshd default
else
    eexec systemctl enable sshd
fi

################################################################################

einfo "Installing ec2-init..."

if eoff "$GENTOO_SYSTEMD"; then
    eexec cp -f /ec2-init.openrc /etc/init.d/ec2-init
    eexec chmod +x /etc/init.d/ec2-init
    eexec rc-update add ec2-init boot
else
    eexec cp -f /ec2-init.script /usr/sbin/ec2-init
    eexec chmod +x /usr/sbin/ec2-init
    eexec cp -f /ec2-init.service /etc/systemd/system/ec2-init.service
    eexec systemctl enable ec2-init
fi

eexec rm /ec2-init.*

################################################################################

einfo "Disabling instance-specific tweaks..."

eexec sed -i -e 's/^MAKEOPTS=/# \0/' /etc/portage/make.conf

################################################################################

if [ -f /user-phase ]; then
    einfo "Executing user phase..."

    eexec chmod +x /user-phase
    eexec /user-phase
    eexec rm /user-phase
fi

################################################################################
