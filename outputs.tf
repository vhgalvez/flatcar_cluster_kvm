# terraform\outputs.tfoutput "ip-addresses" {
  value = {
    for key in var.machines : 
    key => try(libvirt_domain.machine[key].network_interface.0.addresses[0], "IP not assigned")
  }
}
