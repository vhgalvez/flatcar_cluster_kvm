# terraform\outputs.tf
output "ip-addresses" {
  value = { for key in var.machines : key =>
    length(libvirt_domain.machine[key].network_interface) > 0 &&
    length(libvirt_domain.machine[key].network_interface.0.addresses) > 0 ?
    libvirt_domain.machine[key].network_interface.0.addresses[0] :
    "No IP address found"
  }
}
