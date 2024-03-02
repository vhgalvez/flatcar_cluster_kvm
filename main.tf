terraform {
  required_version = ">= 0.13.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
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

resource "libvirt_volume" "vm_disk" {
  for_each       = toset(var.machines)
  name           = "${each.value}-${var.cluster_name}.qcow2"
  base_volume_id = libvirt_volume.base.id
  pool           = libvirt_pool.volumetmp.name
  format         = "qcow2"
}

resource "libvirt_network" "kube_network" {
  name      = "kube_network"
  mode      = "nat"
  addresses = ["10.17.3.0/24"]
}

# Asumiendo que ya tienes archivos de Ignition generados y disponibles localmente
resource "libvirt_volume" "ignition" {
  for_each = toset(var.machines)
  name     = "${each.key}-ignition.qcow2"
  pool     = libvirt_pool.volumetmp.name
  content  = file("${path.module}/ignition_files/${each.key}.ign")
  format   = "raw"
}

resource "libvirt_domain" "machine" {
  for_each = toset(var.machines)

  name   = "${each.value}-${var.cluster_name}"
  vcpu   = var.virtual_cpus
  memory = var.virtual_memory

  network_interface {
    network_id = libvirt_network.kube_network.id
  }

  disk {
    volume_id = libvirt_volume.vm_disk[each.key].id
  }

  disk {
    volume_id = libvirt_volume.ignition[each.key].id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}

 #
 # resource "local_file" "flatcar" {
 #   for_each = data.ct_config.ignition
 #   content  = each.value.rendered
 #   filename = "/var/lib/libvirt/images/${var.cluster_name}/${each.key}.ign"
 # }
