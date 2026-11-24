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
  default = "riscv-ubuntu"
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
  default = "22.04"
  validation {
    condition     = contains(["22.04", "24.04", "26.04"], var.ubuntu_version)
    error_message = "Ubuntu version must be either 22.04, 24.04, or 26.04."
  }
}

locals {
  iso_data = {
    "22.04" = {
      iso_url        = "./ubuntu-22.04.3-preinstalled-server-riscv64+unmatched.img"
      iso_checksum   = "sha256:b6fc820db60fb7b55dfff62afd70b4d65ca9aa5b61fc4cf16314cce36934baf5"
      output_dir     = "disk-image"
      kernel_dir     = "my-riscv-5.15.167-kernel"
      kernel_version = "5.15.167"
    }
    "24.04" = {
      iso_url        = "./ubuntu-24.04-preinstalled-server-riscv64.img"
      iso_checksum   = "sha256:9f1010bfff3d3b2ed3b174f121c5b5002f76ae710a6647ebebbc1f7eb02e63f5"
      output_dir     = "disk-image-24.04"
      kernel_dir     = "my-riscv-6.8.12-kernel"
      kernel_version = "6.8.12"
    }
    "26.04" = {
      # TODO: Fill in the actual base disk image URL and checksum for
      # Ubuntu 26.04 once it is available.
      iso_url        = "./ubuntu-26.04.1-preinstalled-server-riscv64.img"
      iso_checksum   = "sha256:95410744d9702b6d259b18d57e14ab5eda28d7c67eeff36a96f1afd868d19d38"
      output_dir     = "disk-image-26.04"
      kernel_dir     = "my-riscv-7.0.0-kernel"
      kernel_version = "7.0.14"
    }
  }
}

source "qemu" "initialize" {
  cpus             = "4"
  disk_size        = "5000"
  format           = "raw"
  headless         = "true"
  disk_image       = "true"
  boot_command = [
                  "<wait10><enter>",  // If the build process is hanging during login, the `<wait>` commands may need to be adjusted.
                  "<wait300>",
                  // Password checks/updates are slow under emulation, and the
                  // password prompts flush any keys typed ahead of them.
                  "ubuntu<enter><wait10>",
                  "ubuntu<enter><wait10>",
                  "ubuntu<enter><wait10>",
                  "12345678<enter><wait10>",
                  "12345678<enter><wait10>",
                  "<wait30>",
                  "sudo adduser gem5<enter><wait10>",
                  "12345<enter><wait10>",
                  "12345<enter><wait10>",
                  "<enter><enter><enter><enter><enter>y<enter><wait>",
                  "sudo usermod -aG sudo gem5<enter><wait>"
                ]
  iso_checksum     = local.iso_data[var.ubuntu_version].iso_checksum
  iso_urls         = [local.iso_data[var.ubuntu_version].iso_url]
  memory           = "8192"
  output_directory = local.iso_data[var.ubuntu_version].output_dir
  qemu_binary      = "/usr/bin/qemu-system-riscv64"

  // OpenSBI >= 1.6 builds fw_jump.elf as position-independent with a load
  // address of 0x0, which overlaps QEMU's reset ROM; use the raw .bin instead.
  // Ubuntu >= 25.10 userspace targets the RVA23 profile (requires the vector
  // extension, etc.), so the default rv64 CPU hits illegal instructions in init.
  qemuargs       = [  ["-bios", "/usr/lib/riscv64-linux-gnu/opensbi/generic/fw_jump.bin"],
                      ["-machine", "virt"],
                      ["-cpu", "max"],
                      ["-kernel","/usr/lib/u-boot/qemu-riscv64_smode/uboot.elf"],
                      ["-device", "virtio-vga"],
                      ["-device", "qemu-xhci"],
                      ["-device", "usb-kbd"]
                  ]
  shutdown_command = "echo '${var.ssh_password}'|sudo -S shutdown -P now"
  ssh_password     = "${var.ssh_password}"
  ssh_username     = "${var.ssh_username}"
  ssh_wait_timeout = "60m"
  vm_name          = "${var.image_name}"
  ssh_handshake_attempts = "1000"
}

build {
  sources = ["source.qemu.initialize"]


  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/gem5_init.sh"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/after_boot.sh"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/serial-getty@.service"
  }

  provisioner "file" {
    destination = "/home/gem5"
    source      = "${local.iso_data[var.ubuntu_version].kernel_dir}/${local.iso_data[var.ubuntu_version].kernel_version}"
  }
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo --preserve-env=UBUNTU_VERSION,KERNEL_VERSION -S bash '{{ .Path }}'"
    scripts         = ["scripts/post-installation.sh"]
    environment_vars = ["UBUNTU_VERSION=${var.ubuntu_version}",
                         "KERNEL_VERSION=${local.iso_data[var.ubuntu_version].kernel_version}"
                        ]
  }

}
