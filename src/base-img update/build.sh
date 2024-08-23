#!/bin/bash

# Copyright (c) 2024 The Regents of the University of California.
# SPDX-License-Identifier: BSD 3-Clause

PACKER_VERSION="1.10.0"

if [ ! -f ./packer ]; then
    wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip;
    unzip packer_${PACKER_VERSION}_linux_amd64.zip;
    rm packer_${PACKER_VERSION}_linux_amd64.zip;
fi


# Ensure the script is run with two arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path_to_base_image> <output_directory>"
    exit 1
fi

# Assign arguments to variables
BASE_IMAGE_PATH=$1
OUTPUT_DIRECTORY=$2

# Calculate the sha256 checksum of the base image
ISO_CHECKSUM=$(sha256sum "$BASE_IMAGE_PATH" | awk '{ print $1 }')


# Install the needed plugins
./packer init x86-base-image-udpate.pkr.hcl

# Run the packer build command with the variables
packer build -var "base_image_path=$BASE_IMAGE_PATH" -var "output_directory=$OUTPUT_DIRECTORY" -var "iso_checksum=$ISO_CHECKSUM" x86-base-image-udpate.pkr.hcl
