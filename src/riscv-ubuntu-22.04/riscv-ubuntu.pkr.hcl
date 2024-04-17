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
  default = "12345678"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

source "qemu" "initialize" {
  cpus             = "4"
  disk_size        = "5000"
  format           = "raw"
  headless         = "true"
  disk_image       = "true"
  http_directory   = "http"
  boot_command = [
                  "<wait90>",
                  "ubuntu<enter><wait>",
                  "ubuntu<enter><wait>",
                  "ubuntu<enter><wait>",
                  "12345678<enter><wait>",
                  "12345678<enter><wait>",
                  "<wait>",
                ]
  iso_checksum     = "sha256:0363f6fceef18dfc106379a7487af6648dfc7540423d57a36080d9fc53633dcf"
  iso_urls         = ["/home/harshilp/forks/gem5-resources-repo/fresh-riscv-img.img"]
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
    destination = "/home/ubuntu/"
    source      = "files/gem5_init.sh"
  }

  provisioner "file" {
    destination = "/home/ubuntu/"
    source      = "files/after_boot.sh"
  }

  provisioner "file" {
    destination = "/home/ubuntu/"
    source      = "files/serial-getty@.service"
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    scripts         = ["scripts/post-installation.sh"]
    environment_vars = [
      "ISA=riscv",
    ]
  }

}