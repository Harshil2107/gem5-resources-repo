#!/bin/bash

# Copyright (c) 2025 The Regents of the University of California.
# SPDX-License-Identifier: BSD 3-Clause

echo "Installing common packages."


echo "Installing serial service override for autologin after systemd."
mkdir /etc/systemd/system/serial-getty@.service.d/
mv serial-getty@.service-override.conf /etc/systemd/system/serial-getty@.service.d/override.conf

# Installing the packages in this script instead of the user-data
# file during ubuntu autoinstall. The reason is that sometimes
# the package install fails. This method is more reliable.

# On the first boot cloud-init and apt-daily/unattended-upgrades may still be
# running apt, and apt-get fails right away if another process holds the
# dpkg lock. This is much more likely when the guest is emulated (no KVM),
# so wait for them to finish first.
# Match the upgrade itself (/usr/bin/unattended-upgrade), not the
# unattended-upgrade-shutdown helper that runs for the whole uptime. Give up
# after an hour so a stuck process can't hang the build.
cloud-init status --wait > /dev/null 2>&1 || true
for i in $(seq 360); do
    pgrep -x 'apt|apt-get|dpkg' > /dev/null ||
        pgrep -f '/usr/bin/unattended-upgrade( |$)' > /dev/null || break
    echo "Waiting for another apt/dpkg process to finish..."
    sleep 10
done

echo "Installing packages required for gem5-bridge (m5) and libm5."
apt-get update
apt-get install -y scons
apt-get install -y git
apt-get install -y vim
apt-get install -y build-essential

# Add after_boot.sh to bashrc in the gem5 user account
# This will run the script after the user automatically logs in
echo "Adding after_boot.sh to the gem5 user's .bashrc."
echo -e "\nif [ -z \"\$AFTER_BOOT_EXECUTED\" ]; then\n   export AFTER_BOOT_EXECUTED=1\n    /home/gem5/after_boot.sh\nfi\n" >> /home/gem5/.bashrc

# Remove the motd
rm /etc/update-motd.d/*

echo "Installation of common packages done."