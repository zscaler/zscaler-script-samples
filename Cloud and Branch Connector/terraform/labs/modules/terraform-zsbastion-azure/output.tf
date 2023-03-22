output "public_ip" {
  value = azurerm_public_ip.bastion-pip.ip_address
}
output "private_ip" {
  value = azurerm_network_interface.bastion-nic.private_ip_address
}