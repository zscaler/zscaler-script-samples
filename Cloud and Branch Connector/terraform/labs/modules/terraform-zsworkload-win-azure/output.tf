output "private_ip" {
  value = azurerm_network_interface.server-nic.*.private_ip_address
}
# output "public_ip" {
#   value = azurerm_public_ip.workload-pip.ip_address
# }