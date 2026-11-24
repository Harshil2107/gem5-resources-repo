packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "image_name" {
  type    = string
  default = "riscv-ubuntu-npb-24.04"
}

variable "ssh_password" {
  type    = string
  default = "12345"
}

variable "ssh_username" {
  type    = string
  default = "gem5"
}

variable "ubuntu_version" {
  type    = string
  default = "24.04"
  validation {
    condition     = contains(["24.04", "26.04"], var.ubuntu_version)
    error_message = "Ubuntu version must be either 24.04 or 26.04."
  }
}

locals {
  disk_image_data = {
    "24.04" = {
      disk_image_file = "./riscv-ubuntu-24.04-20250515"
      iso_checksum    = "sha256:ddf1ebb56454ef37e88d6de8aefdef7180fc9a2328a3bf8cff02f7a043e7127b"
      output_dir      = "disk-image-riscv-npb"
      disk_size       = "5000"
    }
    "26.04" = {
      # TODO: Point this at the published riscv 26.04 base image once it is
      # uploaded to gem5 resources.
      disk_image_file = "../riscv-fs/riscv-ubuntu-22.04-24.04/disk-image-26.04/riscv-ubuntu"
      iso_checksum    = "sha256:6baa867d16b773e93d805a4c186b333589d32cc852458fbc2eaa7b5b6099c791"
      output_dir      = "disk-image-riscv-npb-26-04"
      # The 26.04 base image has little free space left; the extra space is
      # claimed by growing the root partition in post-installation.sh.
      disk_size       = "7000"
    }
  }
}

source "qemu" "initialize" {
  cpus             = "4"
  disk_size        = local.disk_image_data[var.ubuntu_version].disk_size
  format           = "raw"
  headless         = "true"
  disk_image       = "true"
  // If the build process is hanging during login, the `<wait>` commands may
  // need to be adjusted. Password checks are slow under emulation and the
  // password prompts flush any keys typed ahead of them.
  boot_command = ["<wait300>",
                  "gem5<enter><wait10>",
                  "12345<enter><wait30>",
                  "sudo mount -o remount,rw /<enter><wait10>", // remounting system as read-write as qemu does not like that we have m5 exits in the boot process so it mounts system as read ony.
                  "12345<enter><wait30>",
                  "sudo mv /etc/netplan/50-cloud-init.yaml.bak /etc/netplan/50-cloud-init.yaml<enter><wait10>",
                  "sudo netplan apply<enter><wait10>",
                  "<wait>"
                ]
  iso_checksum     = local.disk_image_data[var.ubuntu_version].iso_checksum
  iso_urls         = [local.disk_image_data[var.ubuntu_version].disk_image_file]
  memory           = "8192"
  output_directory = local.disk_image_data[var.ubuntu_version].output_dir
  qemu_binary      = "/usr/bin/qemu-system-riscv64"

  // OpenSBI >= 1.6 builds fw_jump.elf with a load address of 0x0, which
  // overlaps QEMU's reset ROM; use the raw .bin instead. Ubuntu >= 25.10
  // userspace targets RVA23 (needs the vector extension), hence -cpu max.
  qemuargs       = [  ["-bios", "/usr/lib/riscv64-linux-gnu/opensbi/generic/fw_jump.bin"],
                      ["-machine", "virt"],
                      ["-cpu", "max"],
                      ["-kernel","/usr/lib/u-boot/qemu-riscv64_smode/uboot.elf"],
                      ["-device", "virtio-vga"],
                      ["-device", "qemu-xhci"],
                      ["-device", "usb-kbd"]
                  ]
  // The emulated build takes ~1.5 hours, long enough for a background job
  // (e.g. apt-daily) to hold a shutdown block inhibitor, which makes
  // "shutdown" fail. Wait up to 20 minutes for block inhibitors to clear,
  // then power off ignoring them.
  shutdown_command = "echo '${var.ssh_password}'|sudo -S sh -c 'for i in $(seq 120); do systemd-inhibit --list --no-legend | grep -qw block || break; systemd-inhibit --list; sleep 10; done; systemctl poweroff -i'"
  shutdown_timeout = "30m"
  ssh_password     = "${var.ssh_password}"
  ssh_username     = "${var.ssh_username}"
  ssh_wait_timeout = "60m"
  vm_name          = "${var.image_name}"
  ssh_handshake_attempts = "1000"
}

build {
  sources = ["source.qemu.initialize"]
  provisioner "file" {
    source      = "npb-with-roi/NPB/NPB3.4-OMP"
    destination = "/home/gem5/"
  }

  provisioner "file" {
    source      = "makefiles/riscv/make.def"
    destination = "/home/gem5/NPB3.4-OMP/config/"
  }

  provisioner "file" {
    source      = "npb-hook-files/non-addr-version/hooks.c"
    destination = "/home/gem5/NPB3.4-OMP/common/"
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo --preserve-env=UBUNTU_VERSION -S bash '{{ .Path }}'"
    scripts         = ["scripts/post-installation.sh"]
    environment_vars = ["UBUNTU_VERSION=${var.ubuntu_version}"]
  }
}