// WeSecure: Packer build (VMware). Builds a clean Ubuntu 24.04 via autoinstall,
// provisions the whole box with Ansible, then exports an ISO-free, neutrally-named OVA.
//
//   packer init .
//   packer validate -var-file=build.pkrvars.hcl .
//   packer build   -var-file=build.pkrvars.hcl .
//
// A VirtualBox variant is trivial: swap the source for `virtualbox-iso` (which can
// output OVA directly and drop the ovftool post-processor).

packer {
  required_plugins {
    vmware  = { version = ">= 1.0.0", source = "github.com/hashicorp/vmware" }
    ansible = { version = ">= 1.0.0", source = "github.com/hashicorp/ansible" }
  }
}

variable "iso_url"      { type = string  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso" }
variable "iso_checksum" { type = string  default = "sha256:e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9" }
variable "secrets_file" { type = string  default = "../ansible/secrets.yml" }

source "vmware-iso" "wesecure" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  guest_os_type    = "ubuntu-64"
  cpus             = 2
  memory           = 2048
  disk_size        = 20480
  headless         = true
  http_directory   = "http"
  boot_wait        = "5s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\"<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
  ssh_username           = "ubuntu"
  ssh_password           = "ubuntu"
  ssh_timeout            = "45m"
  ssh_handshake_attempts = "100"
  shutdown_command       = "echo 'ubuntu' | sudo -S shutdown -P now"
  vmx_data = {
    "ethernet0.connectionType" = "nat"   # DHCP, portable (no host-only hardcoding)
  }
}

build {
  name    = "wesecure"
  sources = ["source.vmware-iso.wesecure"]

  provisioner "ansible" {
    playbook_file   = "../ansible/site.yml"
    galaxy_file     = "../ansible/requirements.yml"
    extra_arguments = ["-e", "@${var.secrets_file}", "--become"]
    use_proxy       = false
  }

  // Export an ISO-free, compressed, neutrally-named OVA (matches the release build).
  post-processor "shell-local" {
    inline = [
      "ovftool --acceptAllEulas --compress=6 --name=WeSecure output-wesecure/*.vmx WeSecure.ova"
    ]
  }
}
