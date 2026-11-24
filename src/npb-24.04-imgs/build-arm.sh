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
    echo "Example: $0 24.04 or $0 26.04 false"
    exit 1
fi

# Store the Ubuntu version from the command line argument
ubuntu_version="$1"
use_kvm="${2:-$default_use_kvm}"

# Check if the specified Ubuntu version is valid
if [[ "$ubuntu_version" != "24.04" && "$ubuntu_version" != "26.04" ]]; then
    echo "Error: Invalid Ubuntu version '$ubuntu_version'. Must be '24.04' or '26.04'."
    exit 1
fi

# make the flash0.sh file
mkdir -p files
cd ./files
dd if=/dev/zero of=flash0.img bs=1M count=64
dd if=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd of=flash0.img conv=notrunc
cd ..

# get the base image from gem5 resources
if [ "$ubuntu_version" = "24.04" ]; then
    if [ ! -f ./arm-ubuntu-24.04-20250515 ]; then
        wget https://gem5resources.blob.core.windows.net/dist-gem5-org/dist/develop/images/arm/ubuntu-24-04/arm-ubuntu-24.04-20250515.gz
        gunzip arm-ubuntu-24.04-20250515.gz
    fi
elif [ "$ubuntu_version" = "26.04" ]; then
    # TODO: Download the published arm 26.04 base image once it is uploaded
    # to gem5 resources. Until then, build it with
    # src/ubuntu-generic-diskimages/build-arm.sh 26.04.
    if [ ! -f ../ubuntu-generic-diskimages/arm-disk-image-26-04/arm-ubuntu ]; then
        echo "Error: Build the arm 26.04 base image first with"
        echo "src/ubuntu-generic-diskimages/build-arm.sh 26.04"
        exit 1
    fi
fi

# Install the needed plugins
./packer init arm-npb.pkr.hcl

# Build the image
./packer build -var "ubuntu_version=${ubuntu_version}" -var "use_kvm=${use_kvm}" arm-npb.pkr.hcl
