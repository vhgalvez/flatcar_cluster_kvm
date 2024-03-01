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

resource "null_resource" "prepare_directory" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
    mkdir -p /var/lib/libvirt/images/${var.cluster_name} &&
    sudo chown -R qemu:qemu /var/lib/libvirt/images/${var.cluster_name} &&
    sudo chmod -R 755 /var/lib/libvirt/images/${var.cluster_name}
    EOT
  }
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
  name           = "${each.value}-entorno-testing.qcow2"
  base_volume_id = libvirt_volume.base.id
  pool           = libvirt_pool.volumetmp.name
  format         = "qcow2"
}

resource "libvirt_network" "kube_network" {
  name      = "k8snet"
  mode      = "nat"
  addresses = ["10.17.3.0/24"]
  dns {
    enabled    = true
    local_only = true
  }
  dhcp {
    enabled = true
  }
}

data "ct_config" "ignition" {
  for_each = toset(var.machines)

  content = templatefile("${path.module}/../configs/${each.key}-config.yaml.tmpl", {
    message = "Bienvenido a ${each.key}. Aquí está tu mensaje personalizado.",
    ssh_authorized_keys = join("\n", var.ssh_keys)
  })
}


resource "libvirt_domain" "machine" {
  for_each = toset(var.machines)

  name   = "${each.value}-${var.cluster_name}"
  vcpu   = var.virtual_cpus
  memory = var.virtual_memory

  disk {
    volume_id = libvirt_volume.vm_disk[each.value].id
  }

  network_interface {
    network_id = libvirt_network.kube_network.id
  }

  coreos_ignition = data.ct_config.ignition[each.value].rendered
}
