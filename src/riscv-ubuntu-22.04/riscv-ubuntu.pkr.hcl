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

source "qemu" "initialize" {
  cpus             = "4"
  disk_size        = "5000"
  format           = "raw"
  headless         = "true"
  disk_image       = "true"
  http_directory   = "http"
  boot_command = [
                  "<wait120>",
                  "ubuntu<enter><wait>",
                  "ubuntu<enter><wait>",
                  "ubuntu<enter><wait>",
                  "12345678<enter><wait>",
                  "12345678<enter><wait>",
                  "<wait20>",
                  "sudo adduser gem5<enter><wait10>",
                  "12345<enter><wait10>",
                  "12345<enter><wait10>",
                  "<enter><enter><enter><enter><enter>y<enter><wait>",
                  "sudo usermod -aG sudo gem5<enter><wait>"
                ]
  iso_checksum     = "sha256:32bb0ec61ed38998100ee25934b5c37da345708a09e1dd0d99c0a8a2da0739de"
  iso_urls         = ["./ubuntu-22.04.3-preinstalled-server-riscv64+unmatched.img"]
  memory           = "8192"
  output_directory = "disk-image"
  qemu_binary      = "/usr/bin/qemu-system-riscv64"

  qemuargs       = [  ["-bios", "/usr/lib/riscv64-linux-gnu/opensbi/generic/fw_jump.elf"],
                      ["-machine", "virt"],
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

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    scripts         = ["scripts/post-installation.sh"]
  }

}
