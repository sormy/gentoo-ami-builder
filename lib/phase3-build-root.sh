#!/bin/bash

################################################################################

# %ELIB% - this line indicates that ELIB should be injected below

################################################################################

# global EMERGE_OPTS
# global GENKERNEL_OPTS
# global ENA_PKG

################################################################################

# we need to detect disk device names and partition names
# as disk name could vary depending on instance type
DISK1=$(find_disk1)
DISK2=$(find_disk2)
DISK1P1=$(append_disk_part $DISK1 1)
DISK2P1=$(append_disk_part $DISK2 1)

################################################################################

einfo "Updating configuration..."

eexec env-update
source /etc/profile

################################################################################

einfo "Tuning compiler options..."

CPU_COUNT=$(cat /proc/cpuinfo | grep processor | wc -l)
MAKE_THREADS=$(expr $CPU_COUNT + 1)
MAKE_OPTS="-j$MAKE_THREADS"

cat >> /etc/portage/make.conf << END

# added by gentoo ami builder
CFLAGS="-O2 -pipe -mtune=generic"
MAKEOPTS="$MAKE_OPTS"
END

################################################################################

if [ -e /usr/local/portage ]; then
    einfo "Fixing local overlay ownership..."

    eexec chown -R portage:portage /usr/local/portage
fi

################################################################################

einfo "Installing kernel sources..."

eexec emerge $EMERGE_OPTS sys-kernel/gentoo-sources

################################################################################

einfo "Installing genkernel..."

echo "sys-apps/util-linux static-libs" > /etc/portage/package.use/genkernel

eexec emerge $EMERGE_OPTS sys-kernel/genkernel

################################################################################

einfo "Installing kernel..."

AMAZON_KERNEL_CONFIG=$(find /etc/kernels -type f -name "config-*.amzn*" | head -n 1)
KERNEL_CONFIG="${AMAZON_KERNEL_CONFIG}.bootstrap"

eexec cp -f "$AMAZON_KERNEL_CONFIG" "$KERNEL_CONFIG"

# genkernel won't autoload module XEN/NVME BLKDEV, so we build them into kernel
# IXGBEVF: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sriov-networking.html
eexec sed -i \
    -e '/CONFIG_XEN_BLKDEV_FRONTEND/c\CONFIG_XEN_BLKDEV_FRONTEND=y' \
    -e '/CONFIG_NVME_CORE/c\CONFIG_NVME_CORE=y' \
    -e '/CONFIG_BLK_DEV_NVME/c\CONFIG_BLK_DEV_NVME=y' \
    -e '/CONFIG_IXGBEVF/c\CONFIG_IXGBEVF=y' \
    "$KERNEL_CONFIG"

eexec genkernel all $GENKERNEL_OPTS --makeopts="$MAKE_OPTS" --kernel-config="$KERNEL_CONFIG"

################################################################################

einfo "Installing ENA kernel module..."

eexec emerge $EMERGE_OPTS $ENA_PKG

cat >> /etc/conf.d/modules << END

# added by gentoo ami builder
modules="ena"
END

################################################################################

einfo "Installing bootloader..."

eexec emerge $EMERGE_OPTS sys-boot/grub

cat >> /etc/portage/make.conf << END

# added by gentoo ami builder
GRUB_PLATFORMS="$GRUB_PLATFORMS"
END

cat >> /etc/default/grub << END

# added by gentoo ami builder
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 console=tty0 console=ttyS0,115200n8"
END

eexec grub-install $DISK2
eexec grub-mkconfig -o /boot/grub/grub.cfg

# enable serial console support after boot
eexec sed -i -e 's/^#\(.* ttyS0 .*$\)/\1/' /etc/inittab

################################################################################

einfo "Configuring network..."

eexec ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
eexec rc-update add net.eth0 default

################################################################################

einfo "Configuring SSH..."

eexec passwd -d -l root
eexec rc-update add sshd default

################################################################################

einfo "Disabling keymaps service..."

eexec rc-update delete keymaps boot

################################################################################

einfo "Installing amazon-ec2-init..."

cat > /etc/init.d/amazon-ec2-init << END
#!/sbin/openrc-run

depend() {
    before hostname
    need net.eth0
}

start() {
    local lock="/var/lib/amazon-ec2-init.lock"
    local instance_id="\$(wget -t 2 -T 5 -q -O - http://169.254.169.254/latest/meta-data/instance-id)"

    [ -f "\$lock" ] && [ "\$(cat "\$lock")" = "\$instance_id" ] && exit 0

    einfo "Provisioning instance..."

    eindent
    provision_hostname
    provision_ssh_authorized_keys
    eoutdent

    echo "\$instance_id" > "\$lock"
}

provision_hostname() {
    ebegin "Setting hostname"
    local hostname="\$(wget -t 2 -T 5 -q -O - http://169.254.169.254/latest/meta-data/local-hostname)"
    echo "hostname=\${hostname}" > /etc/conf.d/hostname
    eend \$?
}

provision_ssh_authorized_keys() {
    ebegin "Importing SSH authorized keys"

    [ -e /root/.ssh ] && rm -rf /root/.ssh
    mkdir -p /root/.ssh
    chown root:root /root/.ssh
    chmod 750 /root/.ssh

    local keys=\$(wget -t 2 -T 5 -q -O - http://169.254.169.254/latest/meta-data/public-keys/ \\
        | cut -d = -f 1 \\
        | xargs printf "http://169.254.169.254/latest/meta-data/public-keys/%s/openssh-key\n")

    if [ -n "\${keys}" ]; then
        wget -t 2 -T 5 -q -O - \${keys} > /root/.ssh/authorized_keys
        chown root:root /root/.ssh/authorized_keys
        chmod 640 /root/.ssh/authorized_keys
    fi

    eend \$?
}
END

eexec chmod +x /etc/init.d/amazon-ec2-init

eexec rc-update add amazon-ec2-init boot

################################################################################

einfo "Updating world..."

eexec emerge $EMERGE_OPTS --update --deep --newuse @world

################################################################################

einfo "Disabling instance-specific tweaks..."

eexec sed -i -e 's/^MAKEOPTS=/# \0/' /etc/portage/make.conf

################################################################################
