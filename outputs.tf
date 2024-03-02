# terraform\outputs.tf
output "machine_ips" {
  value = { for k, v in libvirt_domain.machine : k => v.network_interface.0.addresses[0] }
}
