---
title: Building the base x86-ubuntu image
authors:
    - Harshil Patel
---

This document provides instructions to create the "x86-ubuntu" image. This image is a 22.04 Ubuntu image.

## Directory map

- `files`: Files that are copied to the disk image.
- `scripts`: Scripts run on the disk image after installation.
- `http`: cloud-init Ubuntu autoinstall files.
- `disk-image`: The disk image output directory.

## Disk Image

Run `./build.sh` in the `x86-ubuntu` directory to build the disk image.
This will download the packer binary, initialize packer, and build the disk image.

Note: This can take a while to run.
You will see `qemu.initialize: Waiting for SSH to become available...` while the installation is running.
You can watch the installation with a VNC viewer.
See [Troubleshooting](#troubleshooting) for more information.

## Kernel

A kernel is also extracted from the disk image during the post-installation process.
The latest headers and modules are installed using apt, before extracting the kernel using the `extract-vmlinux` script provided in ubuntu. The extracted kernel is placed at `/home/gem5/vmlinux-x86-ubuntu`.
The extracted kernel does not have a version its name, but the kernel version is printed as before the extraction in `post-installation.sh` script. This extracted kernel can be used as a resource for gem5 simulations and is not limited to just be used with this disk image.

The kernel is extracted using packer's file provisioner with `direction=download` which would copy a file from the image to the host machine. The path specifying in the provisioner copies the file `/home/gem5/vmlinux-x86-ubuntu` to the output directory `disk-image`.

## Changes from the base Ubuntu 22.04 image

- The default user is `gem5` with password `12345`.
- The `m5` utility is renamed to `gem5-bridge`.
  - `gem5-bridge` utility is installed in `/usr/local/bin/gem5-bridge`.
  - `gem5-bridge` has a symlink to `m5` for backwards compatibility.
  - `libm5` is installed in `/usr/local/lib/` and the headers for `libm5` are installed in `/usr/local/include/m5`.
- The `.bashrc` file checks to see if there is anything in the `gem5-bridge readfile` command and executes the script if there is.
- The init process is modified to provide better annotations and more exit event. For more details see the [Init Process and Exit events](README.md#init-process-and-exit-events).
  - The `gem5-bridge exit` command is run after the linux kernel initialization by default.
  - If the `no_systemd` boot option is passed, systemd is not run and the user is dropped to a terminal.
  - If the `interactive` boot option is passed, the `gem5-bridge exit` command is not run after the linux kernel initialization.
- Networking is disabled by moving the `/etc/netplan/00-installer-config.yaml` file to `/etc/netplan/00-installer-config.yaml.bak`. The `systemd-networkd-wait-online.service` is also disabled.
  - If you want to enable networking, you need to modify the disk image and move the file `/etc/netplan/00-installer-config.yaml.bak` to `/etc/netplan/00-installer-config.yaml`.
  To re-enable `systemd-networkd-wait-online.service`, first, unmask the service with `sudo systemctl unmask systemd-networkd-wait-online.service` and then enable the service to start with `sudo systemctl enable systemd-networkd-wait-online.service`.
  If you require the service to start immediately without waiting for the next boot then also run the following:
  `sudo systemctl start systemd-networkd-wait-online.service`.

## Extending the Disk Image

### Customization of Post-Installation Processes

- **Replace `gem5_init.sh`**: This script is what executes as the Linux init process (pid=0) immediately after Linux boot. If you have a custom initialization script, replace the default `gem5_init.sh` in both `x86-ubuntu.pkr.hcl` and `post-installation.sh` to integrate your custom initialization process.
- **Replace `gem5_init.sh`**: If you have a custom initialization script, replace the default `gem5_init.sh` in both `x86-ubuntu.pkr.hcl` and `post-installation.sh` to integrate your custom initialization process.

### Handling the After-Boot Script

- **Persistent Execution of `after-boot.sh`**: The `after-boot.sh` script executes at first login.
To avoid its infinite execution, we incorporated a conditional check in `post-installation.sh` similar to the following:

  ```sh
  echo -e "\nif [ -z \"\$AFTER_BOOT_EXECUTED\" ]; then\n   export AFTER_BOOT_EXECUTED=1\n    /home/gem5/after_boot.sh\nfi\n" >> /home/gem5/.bashrc
  ```

  This ensures `after-boot.sh` runs only once per session by setting an environment variable.

### Adjusting File Permissions

- **Setting Permissions for `gem5-bridge`**: Since the default user is not root, `gem5-bridge` requires root permissions. Apply setuid to grant these permissions:

  ```sh
  chmod u+s /path/to/gem5-bridge
  ```

## Creating a Disk Image from Scratch

### Automated Ubuntu Installation

- **Ubuntu Autoinstall**: We leveraged Ubuntu's autoinstall feature for an automated setup process.
- **Acquire `user-data` File**: To get the `user-data` file, install your desired Ubuntu version on a machine or VM. Post-installation, retrieve the `autoinstall-user-data` from `/var/log/installer/autoinstall-user-data` after the system's first reboot.
The `user-data` file in this repo, is made by selecting all default options except a minimal server installation.

### Configuration and Directory Structure

- **Determine QEMU Arguments**: Identify the QEMU arguments required for booting the system. These vary by ISA and mirror the arguments used for booting a disk image in QEMU.
- **Directory Organization**: Arrange your source directory to include the `user-data` file and any additional content. Utilize the `provisioner` section for transferring extra files into the disk image, ensuring all necessary resources are embedded within your custom disk image.

## Troubleshooting

To see what `packer` is doing, you can use the environment variable `PACKER_LOG=INFO` when running `./build.sh`.

Packer seems to have a bug that aborts the VM build after 2-5 minutes regardless of the ssh_timeout setting.
As a workaround, set ssh_handshake_attempts to a high value.
Thus, I have `ssh_handshake_attempts = 1000`.
From <https://github.com/rlaun/packer-ubuntu-22.04>

To see what is happening while packer is running, you can connect with a vnc viewer.
The port for the vnc viewer is shown in the terminal while packer is running.

You can mount the disk image to see what is inside.
Use the following command to mount the disk image:
(note `norecovery` is needed if you get the error "cannot mount ... read-only")

```sh
mkdir x86-ubuntu/mount
sudo mount -o loop,offset=2097152,norecovery x86-ubuntu/x86-ubuntu-image/x86-ubuntu x86-ubuntu/mount
```

Useful documentation: <https://ubuntu.com/server/docs/install/autoinstall>
