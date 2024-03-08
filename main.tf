terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.0"
    }
    ct = {
      source  = "poseidon/ct"
      version = "0.10.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2.0"
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

data "template_file" "vm-configs" {
  for_each = toset(var.machines)
  template = file("${path.module}/configs/${each.key}-config.yaml.tmpl", )

  vars = {
    ssh_keys     = jsonencode(var.ssh_keys)
    name         = each.key
    host_name    = "${each.key}.${var.cluster_name}.${var.cluster_domain}"
    strict       = true
    pretty_print = true
  }
}

data "ct_config" "vm-ignitions" {
  for_each = toset(var.machines)
  content  = data.template_file.vm-configs[each.key].rendered
}

resource "libvirt_ignition" "ignition" {
  for_each = toset(var.machines)
  name     = "${each.key}-ignition"
  pool     = libvirt_pool.volumetmp.name
  content  = data.ct_config.vm-ignitions[each.key].rendered
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

  coreos_ignition = libvirt_ignition.ignition[each.key].id
}

output "ip-addresses" {
  value = { for key, machine in libvirt_domain.machine : key => machine.network_interface.0.addresses[0] }
}