# terraform\outputs.tf
output "ip-addresses" {
  value = { for key in var.machines : key => libvirt_domain.machine[key].network_interface.0.addresses[0] }
}
