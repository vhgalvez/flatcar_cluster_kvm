# terraform\outputs.tf
output "ip-addresses" {
   value = {
     for key, machine in libvirt_domain.machine : key => can(index(machine.network_interface, 0)) ? machine.network_interface[0].addresses[0] : null
   }
}
