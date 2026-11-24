#!/bin/sh

# Copyright (c) 2020 The Regents of the University of California.
# SPDX-License-Identifier: BSD 3-Clause

# install build-essential (gcc and g++ included) and gfortran

if [ "$(uname -m)" = "riscv64" ]; then
    # The riscv root filesystem (partition 1) sits at the end of the disk, so
    # grow it to use any space added by the packer disk_size setting.
    apt-get install -y cloud-guest-utils
    growpart /dev/vda 1
    resize2fs /dev/vda1
fi

#Compile NPB

apt-get install -y gfortran

cd /home/gem5/NPB3.4-OMP/

mkdir bin
make clean
make suite M5_ANNOTATION=1

echo "Disabling network by default"
echo "See README.md for instructions on how to enable network"

# The netplan config file name depends on how the base image was installed,
# not just the Ubuntu version: images installed with the live-server
# autoinstaller (x86 and arm) use 00-installer-config.yaml, while the riscv
# preinstalled images and the 24.04 images use 50-cloud-init.yaml.
if [ -f /etc/netplan/50-cloud-init.yaml ]; then
    mv /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak
elif [ -f /etc/netplan/00-installer-config.yaml ]; then
    mv /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak
else
    echo "Error: No netplan config found to disable (Ubuntu ${UBUNTU_VERSION})."
    exit 1
fi

# Disable systemd service that waits for network to be online
systemctl disable systemd-networkd-wait-online.service
systemctl mask systemd-networkd-wait-online.service
