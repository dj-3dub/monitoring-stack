output "vm_name" {
  value = vsphere_virtual_machine.monitoring.name
}

output "vm_default_ip" {
  value = vsphere_virtual_machine.monitoring.default_ip_address
}
