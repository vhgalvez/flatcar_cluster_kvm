output "machine_ips" {
  value = {
    for k, v in libvirt_domain.machine : k => length(v.network_interface) > 0 ? v.network_interface[0].addresses[0] : null
  }
}