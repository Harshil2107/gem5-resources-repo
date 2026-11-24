#!/bin/bash

# Copyright (c) 2025 The Regents of the University of California.
# SPDX-License-Identifier: BSD 3-Clause

echo "Updating modules."

# moving modules to the correct location
mv /home/gem5/7.0.14 /lib/modules/7.0.14
depmod --quick -a 7.0.14
update-initramfs -u -k 7.0.14

echo "Modules updated."
