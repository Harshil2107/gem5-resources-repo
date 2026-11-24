#!/bin/bash

# Copyright (c) 2024 The Regents of the University of California.
# SPDX-License-Identifier: BSD 3-Clause

PACKER_VERSION="1.10.0"

if [ ! -f ./packer ]; then
    wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip;
    unzip packer_${PACKER_VERSION}_linux_amd64.zip;
    rm packer_${PACKER_VERSION}_linux_amd64.zip;
fi

# Check if the Ubuntu version variable is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <ubuntu_version>"
    echo "Example: $0 24.04 or $0 26.04"
    exit 1
fi

# Store the Ubuntu version from the command line argument
ubuntu_version="$1"

# Check if the specified Ubuntu version is valid
if [[ "$ubuntu_version" != "24.04" && "$ubuntu_version" != "26.04" ]]; then
    echo "Error: Invalid Ubuntu version '$ubuntu_version'. Must be '24.04' or '26.04'."
    exit 1
fi

if [ "$ubuntu_version" = "24.04" ]; then
    if [ ! -f riscv-ubuntu-24.04-20250515 ]; then
        wget https://dist.gem5.org/dist/develop/images/riscv/ubuntu-24-04/riscv-ubuntu-24.04-20250515.gz
        gunzip riscv-ubuntu-24.04-20250515.gz;
    fi
elif [ "$ubuntu_version" = "26.04" ]; then
    # TODO: Download the published riscv 26.04 base image once it is uploaded
    # to gem5 resources. Until then, build it with
    # src/riscv-fs/riscv-ubuntu-22.04-24.04/build.sh 26.04.
    if [ ! -f ../riscv-fs/riscv-ubuntu-22.04-24.04/disk-image-26.04/riscv-ubuntu ]; then
        echo "Error: Build the riscv 26.04 base image first with"
        echo "src/riscv-fs/riscv-ubuntu-22.04-24.04/build.sh 26.04"
        exit 1
    fi
fi

./packer init riscv-ubuntu-24-04-gapbs.pkr.hcl
./packer build -var "ubuntu_version=${ubuntu_version}" riscv-ubuntu-24-04-gapbs.pkr.hcl
