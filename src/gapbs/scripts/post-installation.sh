# We need to resize the partition to use the full disk space as
# we increased the disk size of the base image and need the
# partition to use the full disk size. Do this before installing packages,
# otherwise libboost-all-dev can fill the original, smaller partition.
echo "Starting partition resizing..."

if [ "$(uname -m)" = "riscv64" ]; then
    # On the riscv images the root filesystem is partition 1, which sits
    # after the boot partitions at the end of the disk, so grow it in place.
    apt-get install -y cloud-guest-utils
    growpart /dev/vda 1
    resize2fs /dev/vda1
else
    # Run fdisk to resize /dev/vda2
    (
      echo d        # Delete partition
      echo 2        # Select partition 2 (assuming it's /dev/vda2)
      echo n        # Create new partition
      echo 2        # Partition number 2
      echo          # Default first sector (same as before)
      echo          # Default last sector (expand to full size)
      echo N        # Keep the existing ext4 signature
      echo w        # Write changes
    ) | sudo fdisk /dev/vda

    # Resize the filesystem to use the expanded partition
    sudo resize2fs /dev/vda2
fi

echo "Partition resizing completed successfully!"

# Install the necessary packages
apt-get install -y build-essential libboost-all-dev

echo "Installing GAP Benchmark Suite"
cd gapbs

# Build the benchmark suite
make clean
make

cd ..
mkdir graphs
cd graphs
wget https://snap.stanford.edu/data/facebook_combined.txt.gz
gunzip facebook_combined.txt.gz
mv facebook_combined.txt facebook_combined.el

wget https://snap.stanford.edu/data/soc-LiveJournal1.txt.gz
gunzip soc-LiveJournal1.txt.gz
sed -i '/^#/d' soc-LiveJournal1.txt # Remove comments from the file as they break the benchmark
mv soc-LiveJournal1.txt soc-LiveJournal1.el # Rename the file to .el to match the benchmark's expectations

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