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
    condition     = contains(["24.04", "26.04"], var.ubuntu_version)
    error_message = "Ubuntu version must be either 24.04 or 26.04."
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
  disk_image_data = {
    "24.04" = {
      disk_image_file     = "./arm-ubuntu-24.04-20250515"
      iso_checksum        = "sha256:71698e2b3e424402b49f92f667a73eb372ed24cf0e1751099ee1c6c4f1944483"
      output_dir          = "disk-image-arm-npb"
      disk_size           = "4600"
      netplan_restore_cmd = "sudo mv /etc/netplan/50-cloud-init.yaml.bak /etc/netplan/50-cloud-init.yaml"
    }
    "26.04" = {
      # TODO: Point this at the published arm 26.04 base image once it is
      # uploaded to gem5 resources.
      disk_image_file     = "../ubuntu-generic-diskimages/arm-disk-image-26-04/arm-ubuntu"
      iso_checksum        = "sha256:b3539f2a0a74d47b920ec0808122bb9f7ffba699306d29add950e0e78eb5bfc8"
      output_dir          = "disk-image-arm-npb-26-04"
      disk_size           = "10000"
      netplan_restore_cmd = "sudo mv /etc/netplan/00-installer-config.yaml.bak /etc/netplan/00-installer-config.yaml"
    }
  }

  qemuargs_base = [
    ["-boot", "order=dc"],
    ["-bios", "./files/flash0.img"],
    ["-machine", "virt"],
    ["-machine", "gic-version=3"],
    ["-device", "virtio-gpu-pci"],
    ["-device", "qemu-xhci"],
    ["-device", "usb-kbd"],
  ]

  qemuargs_kvm = concat(local.qemuargs_base, [
    ["-cpu", "host"],
    ["-enable-kvm"]
  ])

  # Without KVM (e.g. building on an x86 host) the guest is emulated, so give
  # the boot and logins more time. Don't use "-cpu max": QEMU 9.0 aborts with
  # "regime_is_user: code should not be reached" when booting 26.04 with it.
  qemuargs_no_kvm = concat(local.qemuargs_base, [
    ["-cpu", "cortex-a57"]
  ])

  qemuargs  = var.use_kvm == "true" ? local.qemuargs_kvm : local.qemuargs_no_kvm
  boot_wait = var.use_kvm == "true" ? "<wait130>" : "<wait300>"
  step_wait = var.use_kvm == "true" ? "<wait>" : "<wait30>"
}

source "qemu" "initialize" {
  boot_command     = [local.boot_wait,
                      "gem5<enter>${local.step_wait}",
                      "12345<enter>${local.step_wait}",
                      "${local.disk_image_data[var.ubuntu_version].netplan_restore_cmd}<enter>${local.step_wait}",
                      "12345<enter>${local.step_wait}",
                      "sudo netplan apply<enter>${local.step_wait}",
                      "<wait>"]
  cpus             = "4"
  disk_size        = local.disk_image_data[var.ubuntu_version].disk_size
  format           = "raw"
  headless         = "true"
  disk_image       = "true"
  iso_checksum     = local.disk_image_data[var.ubuntu_version].iso_checksum
  iso_urls         = [local.disk_image_data[var.ubuntu_version].disk_image_file]
  memory           = "8192"
  output_directory = local.disk_image_data[var.ubuntu_version].output_dir
  qemu_binary      = "/usr/bin/qemu-system-aarch64"
  qemuargs         = local.qemuargs
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
    source      = "npb-with-roi/NPB/NPB3.4-OMP"
    destination = "/home/gem5/"
  }

  provisioner "file" {
    source      = "makefiles/ARM/make.def"
    destination = "/home/gem5/NPB3.4-OMP/config/"
  }

  provisioner "file" {
    source      = "npb-hook-files/addr-version/hooks.c"
    destination = "/home/gem5/NPB3.4-OMP/common/"
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo --preserve-env=UBUNTU_VERSION -S bash '{{ .Path }}'"
    scripts         = ["scripts/post-installation.sh"]
    environment_vars = ["UBUNTU_VERSION=${var.ubuntu_version}"]
  }

}
