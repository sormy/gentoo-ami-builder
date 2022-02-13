#!/bin/bash

################################################################################

# %ELIB% - this line indicates that ELIB should be injected below

################################################################################

# global GENTOO_STAGE3

################################################################################

# exit if not x32 stage3 or if x32 support has already built into currently loaded kernel
if [ "$GENTOO_STAGE3" != "x32-openrc" ] || grep -q "^CONFIG_X86_X32=y$" < "/boot/config-$(uname -r)"; then
    exit
fi

################################################################################

einfo "Rebuilding amazon kernel with x32 support..."

einfo "Installing kernel build tools..."

eexec yum -y group install "Development Tools"
eexec yum -y install ncurses-devel bison flex elfutils-libelf-devel openssl-devel

einfo "Downloading amazon kernel sources..."

KERNEL_VERSION=$(cut -d ' ' -f 3 < /proc/version)
KERNEL_AMZN_BRANCH="amazon-$(cut -d ' ' -f 3 < /proc/version | sed -e 's/-.*$//' -e 's/\.[^.]*$//').y/master"

eexec git clone --single-branch --branch "${KERNEL_AMZN_BRANCH}" \
    "https://github.com/amazonlinux/linux.git"
eexec cd linux

einfo "Patching amazon kernel config..."

eexec cp -v "/boot/config-${KERNEL_VERSION}" ".config"
eexec sed -i -e '/CONFIG_X86_X32[ =]/c\CONFIG_X86_X32=y' ".config"

einfo "Configuring amazon kernel..."

yes "" | eexec make oldconfig

einfo "Building amazon kernel..."

eexec make -j "$(nproc)"

einfo "Installing new amazon kernel..."

KERNEL_VERSION_NEW="$(make kernelversion)+"

eexec make modules_install
eexec cp -v ".config" "/boot/config-${KERNEL_VERSION_NEW}"
eexec cp -v "arch/x86_64/boot/bzImage" "/boot/vmlinuz-${KERNEL_VERSION_NEW}"
eexec dracut --hostonly --kver "${KERNEL_VERSION_NEW}"

einfo "Patching bootloader configuration..."

KERNEL_FILE="/boot/vmlinuz-${KERNEL_VERSION_NEW}"
INITRAMFS_FILE="/boot/initramfs-${KERNEL_VERSION_NEW}.img"

GRUB_CONFIG_SEARCH="/boot/grub/menu.lst /boot/grub/grub.cfg /boot/grub2/grub.cfg"

for GRUB_CONFIG in $GRUB_CONFIG_SEARCH; do
    if [ -e "$GRUB_CONFIG" ]; then
        eexec sed -i \
            -e 's!/boot/\(vmlinuz\|kernel\)-\S\+!'"$KERNEL_FILE"'!g' \
            -e 's!/boot/initramfs-\S\+!'"$INITRAMFS_FILE"'!g' \
            "$GRUB_CONFIG"
    fi
done
