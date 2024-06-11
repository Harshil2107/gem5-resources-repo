#!/bin/bash

# Copyright (c) 2024 The Regents of the University of California.
# SPDX-License-Identifier: BSD 3-Clause

PACKER_VERSION="1.10.0"

if [ ! -f ./packer ]; then
    wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip;
    unzip packer_${PACKER_VERSION}_linux_amd64.zip;
    rm packer_${PACKER_VERSION}_linux_amd64.zip;
fi


wget https://old-releases.ubuntu.com/releases/jammy/ubuntu-22.04.3-preinstalled-server-riscv64+unmatched.img.xz
unxz ubuntu-22.04.3-preinstalled-server-riscv64+unmatched.img.xz

# Install the needed plugins
./packer init riscv-ubuntu.pkr.hcl

# Build the image
./packer build riscv-ubuntu.pkr.hcl
