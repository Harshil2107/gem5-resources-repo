---
title: GAP Benchmark Suite (GAPBS) tests
tags:
    - x86
    - fullsystem
permalink: resources/gapbs
shortdoc: >
    This resource implementes the [GAP benchmark suite](http://gap.cs.berkeley.edu/benchmark.html).
author: ["Harshil Patel"]
license: BSD-3-Clause
---

This document provides instructions to create a GAP Benchmark Suite (GAPBS) disk image, which, along with an example script, may be used to run GAPBS within gem5 simulations. The example script uses a pre-built disk-image.

A pre-built disk image, for X86, can be found, gzipped, here: <add link>

## What's on the disk?

- username: gem5
- password: 12345

- The `gem5-bridge`(m5) utility is installed in `/usr/local/bin/gem5-bridge`.
- `libm5` is installed in `/usr/local/lib/`.
- The headers for `libm5` are installed in `/usr/local/include/gem5-bridge`.
- `gapbs` benchmark sutie with ROI annotations

Thus, you should be able to build packages on the disk and easily link to the gem5-bridge library.

The disk has network disabled by default to improve boot time in gem5.

If you want to enable networking, you need to modify the disk image and move the file `/etc/netplan/00-installer-config.yaml.bak` to `/etc/netplan/00-installer-config.yaml`.

## Building the Disk Image

Assuming that you are in the `src/gapbs/` directory, run

```sh
./build.sh          # the script downloading packer binary and building the disk image
```

After this process succeeds, the disk image can be found on the `src/gapbs/disk-image-ubuntu-24-04`.

This gapbs image uses the prebuilt ubuntu 24.04 image as a base image. The gapbs image also throws the same exit events as the base image.

Each benchmark also has its regions of intrests annotated and they throw a `gem5-bridge workbegin` and `gem5-bridge workend` exit event.

## Init Process and Exit Events

This section outlines the disk image's boot process variations and the impact of specific boot parameters on its behavior.
By default, the disk image boots with systemd in a non-interactive mode.
Users can adjust this behavior through kernel arguments at boot time, influencing the init system and session interactivity.

### Boot Parameters

The disk image supports two main kernel arguments to adjust the boot process:

- `no_systemd=true`: Disables systemd as the init system, allowing the system to boot without systemd's management.
- `interactive=true`: Enables interactive mode, presenting a shell prompt to the user for interactive session management.

Combining these parameters yields four possible boot configurations:

1. **Default (Systemd, Non-Interactive)**: The system uses systemd for initialization and runs non-interactively.
2. **Systemd and Interactive**: Systemd initializes the system, and the boot process enters an interactive mode, providing a user shell.
3. **Without Systemd and Non-Interactive**: The system boots without systemd and proceeds non-interactively, executing predefined scripts.
4. **Without Systemd and Interactive**: Boots without systemd and provides a shell for interactive use.

### Note on Print Statements and Exit Events

- The bold points in the sequence descriptions are `printf` statements in the code, indicating key moments in the boot process.
- The `**` symbols mark gem5 exit events, essential for simulation purposes, dictating system shutdown or reboot actions based on the configured scenario.

### Boot Sequences

#### Default Boot Sequence (Systemd, Non-Interactive)

- Kernel output
- **Kernel Booted print message** **
- Running systemd print message
- Systemd output
- autologin
- **Running after_boot script** **
- Print indicating **non-interactive** mode
- **Reading run script file**
- Script output
- Exit **

#### With Systemd and Interactive

- Kernel output
- **Kernel Booted print message** **
- Running systemd print message
- Systemd output
- autologin
- **Running after_boot script** **
- Shell

#### Without Systemd and Non-Interactive

- Kernel output
- **Kernel Booted print message** **
- autologin
- **Running after_boot script** **
- Print indicating **non-interactive** mode
- **Reading run script file**
- Script output
- Exit **

#### Without Systemd and Interactive

- Kernel output
- **Kernel Booted print message** **
- autologin
- **Running after_boot script** **
- Shell

This detailed overview provides a foundational understanding of how different boot configurations affect the system's initialization and mode of operation.
By selecting the appropriate parameters, users can customize the boot process for diverse environments, ranging from automated setups to hands-on interactive sessions.