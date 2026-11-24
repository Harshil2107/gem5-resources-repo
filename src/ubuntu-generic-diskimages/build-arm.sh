#!/bin/bash

# Copyright (c) 2024 The Regents of the University of California.
# SPDX-License-Identifier: BSD 3-Clause

PACKER_VERSION="1.10.0"

# Download the packer binary for the host architecture. Building on an arm64
# host can use KVM; on any other host the guest is emulated (use_kvm=false).
if [ "$(uname -m)" = "aarch64" ]; then
    packer_arch="arm64"
    default_use_kvm="true"
else
    packer_arch="amd64"
    default_use_kvm="false"
fi

if [ ! -f ./packer ]; then
    wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_${packer_arch}.zip;
    unzip packer_${PACKER_VERSION}_linux_${packer_arch}.zip;
    rm packer_${PACKER_VERSION}_linux_${packer_arch}.zip;
fi

# Check if the Ubuntu version variable is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <ubuntu_version> [use_kvm]"
    echo "Example: $0 22.04 or $0 24.04 or $0 26.04 false"
    exit 1
fi

# Store the Ubuntu version from the command line argument
ubuntu_version="$1"
use_kvm="${2:-$default_use_kvm}"

# Check if the specified Ubuntu version is valid
if [[ "$ubuntu_version" != "22.04" && "$ubuntu_version" != "24.04" && "$ubuntu_version" != "26.04" ]]; then
    echo "Error: Invalid Ubuntu version '$ubuntu_version'. Must be '22.04', '24.04', or '26.04'."
    exit 1
fi

# make the flash0.sh file
cd ./files
dd if=/dev/zero of=flash0.img bs=1M count=64
dd if=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd of=flash0.img conv=notrunc
cd ..

# Install the needed plugins
./packer init ./packer-scripts/arm-ubuntu.pkr.hcl

# Build the image with the specified Ubuntu version
./packer build -var "ubuntu_version=${ubuntu_version}" -var "use_kvm=${use_kvm}" ./packer-scripts/arm-ubuntu.pkr.hcl
