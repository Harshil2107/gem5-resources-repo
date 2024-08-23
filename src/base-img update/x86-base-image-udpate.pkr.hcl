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
  default = "x86-ubuntu-24-04" # default name can be updated
}

variable "ssh_password" {
  type    = string
  default = "12345" # Update ssh_password if it different for the base image
}

variable "ssh_username" {
  type    = string
  default = "gem5" # Update user if it is different for the base image
}

variable "output_directory" {
  type    = string
  default = "disk-image-ubuntu-24-04"  # Default directory, can be overridden by script
}

variable "base_image_path" {
  type    = string
}

variable "iso_checksum" {
  type    = string
}

source "qemu" "initialize" {
  accelerator      = "kvm"
  boot_command     = [] # If you want packer to type any commands or anything else to the terminal after booting, edit this parameter
  cpus             = "4"
  disk_size        = "5000"
  format           = "raw"
  headless         = "true"
  disk_image       = "true"
  iso_checksum     = "sha256:${var.iso_checksum}"
  iso_urls         = ["${var.base_image_path}"]
  memory           = "8192"
  output_directory = "${var.output_directory}"
  qemu_binary      = "/usr/bin/qemu-system-x86_64"
  qemuargs         = [["-cpu", "host"], ["-display", "none"]]
  shutdown_command = "echo '${var.ssh_password}'|sudo -S shutdown -P now"
  ssh_password     = "${var.ssh_password}"
  ssh_username     = "${var.ssh_username}"
  ssh_wait_timeout = "60m"
  vm_name          = "${var.image_name}"
  ssh_handshake_attempts = "1000"
}

build {
  sources = ["source.qemu.initialize"]

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    scripts         = ["scripts/post-installation.sh"] # this script is blank, add anything you want to run on the image after image is booted
    expect_disconnect = true
  }



}