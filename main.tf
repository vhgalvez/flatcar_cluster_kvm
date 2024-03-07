terraform {
  required_version = ">= 0.13.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.6"
    }
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.13.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

provider "ct" {}

resource "libvirt_network" "kube_network" {
  name      = "kube_network"
  mode      = "nat"
  addresses = ["10.17.3.0/24"]
}

resource "libvirt_pool" "volumetmp" {
  name = var.cluster_name
  type = "dir"
  path = "/var/lib/libvirt/images/${var.cluster_name}"
}

resource "libvirt_volume" "base" {
  name   = "${var.cluster_name}-base"
  source = var.base_image
  pool   = libvirt_pool.volumetmp.name
  format = "qcow2"
}


data "ct_config" "ignition" {
  for_each = toset(var.machines)

  content = templatefile("${path.module}/configs/${each.value}-config.yaml.tmpl", {
    ssh_keys = var.ssh_keys
    message  = "Welcome to Flatcar Linux!"
  })
  strict       = true
  pretty_print = true
}


resource "libvirt_volume" "vm_disk" {
  for_each       = toset(var.machines)
  name           = "${each.key}-${var.cluster_name}.qcow2"
  base_volume_id = libvirt_volume.base.id
  pool           = libvirt_pool.volumetmp.name
  format         = "qcow2"
}

resource "libvirt_domain" "machine" {
  for_each = toset(var.machines)

  name   = each.key
  vcpu   = var.virtual_cpus
  memory = var.virtual_memory

  network_interface {
    network_id = libvirt_network.kube_network.id
  }

  disk {
    volume_id = libvirt_volume.vm_disk[each.key].id
  }

  coreos_ignition = data.ct_config.ignition[each.key].rendered
}

output "ip-addresses" {
  value = { for key, machine in libvirt_domain.machine : key => machine.network_interface.0.addresses[0] }
}
