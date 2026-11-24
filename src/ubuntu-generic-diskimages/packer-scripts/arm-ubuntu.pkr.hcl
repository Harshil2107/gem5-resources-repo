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
  default = "arm-ubuntu"
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
    condition     = contains(["22.04", "24.04", "26.04"], var.ubuntu_version)
    error_message = "Ubuntu version must be either 22.04, 24.04, or 26.04."
  }
}

locals {
  iso_data = {
    "22.04" = {
      iso_url       = "https://old-releases.ubuntu.com/releases/jammy/ubuntu-22.04-live-server-arm64.iso"
      iso_checksum  = "sha256:c209ab013280d3cd26a344def60b7b19fbb427de904ea285057d94ca6ac82dd5"
      output_dir    = "arm-disk-image-22-04"
      http_directory = "http/arm-22-04"
      modules_dir = "kernel-and-modules/arm-ubuntu-22.04/my-arm-5.15.168-kernel/5.15.168"
      disk_size     = "4600"
    }
    "24.04" = {
      iso_url       = "https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04-live-server-arm64.iso"
      iso_checksum  = "sha256:d2d9986ada3864666e36a57634dfc97d17ad921fa44c56eeaca801e7dab08ad7"
      output_dir    = "arm-disk-image-24-04"
      http_directory = "http/arm-24-04"
      modules_dir = "kernel-and-modules/arm-ubuntu-24.04/my-arm-6.8.12-kernel/6.8.12"
      disk_size     = "4600"
    }
    "26.04" = {
      iso_url       = "https://cdimage.ubuntu.com/releases/26.04/release/ubuntu-26.04.1-live-server-arm64.iso"
      iso_checksum  = "sha256:af78753c94b924c85c4964c670692a853f7c80299a4064e317edad95462e3168"
      output_dir    = "arm-disk-image-26-04"
      http_directory = "http/arm-26-04"
      modules_dir = "kernel-and-modules/arm-ubuntu-26.04/my-arm-7.0.22-kernel/7.0.14"
      disk_size     = "10000"
    }
  }
}

variable "use_kvm" {
  type    = string
  default = "true"
  validation {
    condition     = contains(["true", "false"], var.use_kvm)
    error_message = "KVM option must be either 'true' or 'false'."
  }
}

locals {
  qemuargs_base = [
    ["-boot", "order=dc"],
    ["-bios", "./files/flash0.img"],
    ["-machine", "virt"],
    ["-machine", "gic-version=3"],
    ["-device", "virtio-gpu-pci"],
    ["-device", "qemu-xhci"],
    ["-device", "usb-kbd"],
  ]

  qemuargs_kvm = concat(local.qemuargs_base,[
    ["-cpu", "host"],
    ["-enable-kvm"]
  ])

  qemuargs_no_kvm = concat(local.qemuargs_base,[
    ["-cpu", "cortex-a57"]
  ])

  qemuargs = var.use_kvm == "true" ? local.qemuargs_kvm : local.qemuargs_no_kvm

  # Without KVM the guest is emulated. The GRUB menu shows from ~10s to ~40s
  # after start, so type "c" in the middle of that window, and give the
  # much slower install more time before SSH comes up.
  boot_wait        = var.use_kvm == "true" ? "10s" : "20s"
  ssh_wait_timeout = var.use_kvm == "true" ? "60m" : "300m"
}

source "qemu" "initialize" {
  boot_command     = [
                      "c<wait>",
                      "linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/ --- ",
                      "<enter><wait>",
                      "initrd /casper/initrd",
                      "<enter><wait>",
                      "boot",
                      "<enter>",
                      "<wait>"
                      ]
  boot_wait        = local.boot_wait
  cpus             = "4"
  disk_size        = local.iso_data[var.ubuntu_version].disk_size
  format           = "raw"
  headless         = "true"
  http_directory   = local.iso_data[var.ubuntu_version].http_directory
  iso_checksum     = local.iso_data[var.ubuntu_version].iso_checksum
  iso_urls         = [local.iso_data[var.ubuntu_version].iso_url]
  memory           = "8192"
  output_directory = local.iso_data[var.ubuntu_version].output_dir
  qemu_binary      = "/usr/bin/qemu-system-aarch64"
  qemuargs         = local.qemuargs
  shutdown_command = "echo '${var.ssh_password}'|sudo -S shutdown -P now"
  ssh_password     = "${var.ssh_password}"
  ssh_username     = "${var.ssh_username}"
  ssh_wait_timeout = local.ssh_wait_timeout
  vm_name          = "${var.image_name}"
  ssh_handshake_attempts = "1000"
}

build {
  sources = ["source.qemu.initialize"]

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/exit.sh"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/arm/gem5_init.sh"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/arm/after_boot.sh"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/serial-getty@.service-override.conf"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "${local.iso_data[var.ubuntu_version].modules_dir}"
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo --preserve-env=ISA,UBUNTU_VERSION -S bash '{{ .Path }}'"
    scripts         = ["scripts/install-common-packages.sh",
                       "scripts/increase-system-entropy-for-arm-disk.sh",
                       "scripts/update-modules-arm-${var.ubuntu_version}.sh",
                       "scripts/update-gem5-init.sh",
                       "scripts/install-gem5-bridge.sh",
                       "scripts/install-user-packages.sh",
                      ]
    environment_vars = ["ISA=arm64", "UBUNTU_VERSION=${var.ubuntu_version}"]
    expect_disconnect = true
  }

  provisioner "shell" {
    scripts =  ["scripts/install-user-benchmarks.sh"]
    environment_vars = ["UBUNTU_VERSION=${var.ubuntu_version}"]
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo --preserve-env=ISA,UBUNTU_VERSION -S bash '{{ .Path }}'"
    scripts = ["scripts/disable-systemd-services-arm.sh","scripts/disable-network.sh"]
    environment_vars = ["UBUNTU_VERSION=${var.ubuntu_version}"]
    expect_disconnect = true
  }

}
