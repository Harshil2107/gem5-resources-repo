#!/bin/bash

# Copyright (c) 2024 The Regents of the University of California.
# SPDX-License-Identifier: BSD 3-Clause

echo 'Post Installation Started'

# Ensure the UBUNTU_VERSION and KERNEL_VERSION environment variables are set
if [ -z "$UBUNTU_VERSION" ]; then
  echo "Error: UBUNTU_VERSION environment variable is not set."
  exit 1
fi

if [ -z "$KERNEL_VERSION" ]; then
  echo "Error: KERNEL_VERSION environment variable is not set."
  exit 1
fi

echo 'installing packages'
apt-get update
apt-get install -y scons
apt-get install -y git
apt-get install -y vim
apt-get install -y build-essential

echo "Installing serial service for autologin after systemd"
mv /home/gem5/serial-getty@.service /lib/systemd/system/


systemctl disable boot-efi.mount
systemctl mask boot-efi.mount
systemctl daemon-reload


mv /home/gem5/${KERNEL_VERSION} /lib/modules/${KERNEL_VERSION}
depmod --quick -a ${KERNEL_VERSION}
update-initramfs -u -k ${KERNEL_VERSION}

# Giving execute permissions to the after_boot.sh script
chmod 4577 /home/gem5/after_boot.sh
chmod u+s /home/gem5/after_boot.sh

echo "Installing the gem5 init script in /sbin"
mv /home/gem5/gem5_init.sh /sbin
mv /sbin/init /sbin/init.old
ln -s /sbin/gem5_init.sh /sbin/init
chmod +x /sbin/gem5_init.sh
# Add after_boot.sh to bashrc in the gem5 user account
# This will run the script after the user automatically logs in
echo -e "\nif [ -z \"\$AFTER_BOOT_EXECUTED\" ]; then\n   export AFTER_BOOT_EXECUTED=1\n    /home/gem5/after_boot.sh\nfi\n" >> /home/gem5/.bashrc

# Remove the motd
rm /etc/update-motd.d/*

# Build and install the gem5-bridge (m5) binary, library, and headers
echo "Building and installing gem5-bridge (m5) and libm5"

# Just get the files we need
git clone https://github.com/gem5/gem5.git --depth=1 --filter=blob:none --no-checkout --sparse --single-branch --branch=stable
pushd gem5
# Checkout just the files we need
git sparse-checkout add util/m5
git sparse-checkout add util/gem5_bridge
git sparse-checkout add include
git checkout
# Install the headers globally so that other benchmarks can use them
cp -r include/gem5 /usr/local/include/

# Build the library and binary
pushd util/m5
scons riscv.CROSS_COMPILE='' build/riscv/out/m5
cp build/riscv/out/m5 /usr/local/bin/
cp build/riscv/out/libm5.a /usr/local/lib/
popd
popd

# rename the m5 binary to gem5-bridge
mv /usr/local/bin/m5 /usr/local/bin/gem5-bridge
# Set the setuid bit on the m5 binary
chmod 4755 /usr/local/bin/gem5-bridge
chmod u+s /usr/local/bin/gem5-bridge

#create a symbolic link to the gem5 binary for backward compatibility
ln -s /usr/local/bin/gem5-bridge /usr/local/bin/m5

# delete the git repo for gem5
rm -rf gem5
echo "Done building and installing gem5-bridge (m5) and libm5"

# You can extend this script to install your own packages here.

# Disable network by default
echo "Disabling network by default"
echo "See README.md for instructions on how to enable network"

# The netplan config file name depends on the Ubuntu version.
if [ "${UBUNTU_VERSION}" = "22.04" ]; then
    mv /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak
elif [ "${UBUNTU_VERSION}" = "24.04" ]; then
    mv /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak
elif [ "${UBUNTU_VERSION}" = "26.04" ]; then
    mv /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak
else
    echo "Error: Unsupported UBUNTU_VERSION '${UBUNTU_VERSION}'."
    exit 1
fi

# Disable systemd service that waits for network to be online
systemctl disable systemd-networkd-wait-online.service
systemctl mask systemd-networkd-wait-online.service

# Disable and mask cloud-init services
echo "Disabling cloud-init services"
# Disable systemd targets for cloud-init that wait for its completion
systemctl disable cloud-init.target
systemctl mask cloud-init.target

# The riscv image starts from Ubuntu's preinstalled server image, which keeps
# services that the x86/arm minimal installs don't have or disable (see
# ubuntu-generic-diskimages/scripts/disable-systemd-services-arm.sh). They
# are not needed in gem5 and slow the simulated boot down a lot. Not every
# unit exists in every Ubuntu version, so ignore the ones that are missing.
echo "Disabling systemd services not needed in gem5"
for unit in \
    multipathd.service multipathd.socket \
    snapd.service snapd.socket snapd.seeded.service snapd.apparmor.service \
    lxd-installer.socket \
    apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service \
    fstrim.timer \
    accounts-daemon.service \
    lvm2-monitor.service \
    apparmor.service \
    udisks2.service \
    chrony.service systemd-timesyncd.service \
    rsyslog.service \
    networkd-dispatcher.service; do
    systemctl disable "$unit" || true
done
for unit in ModemManager.service \
    plymouth-start.service plymouth-quit.service plymouth-read-write.service; do
    systemctl mask "$unit" || true
done
systemctl set-default multi-user.target

echo "Post Installation Done"
