resource "azurerm_network_security_group" "lin-server-nsg" {
  count               = var.lin_vm_count
  name                = "${var.name_prefix}-lin-server-${count.index + 1}-nsg-${var.resource_tag}"
  location            = var.location
  resource_group_name = var.resource_group
  security_rule {
    name                       = "SSH"
    priority                   = 4004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "RDP"
    priority                   = 4005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }
  # Enable if troubleshooting is necessary out-of-band from Guacamole
  # security_rule {
  #   name                       = "RDP-Pub"
  #   priority                   = 4006
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "3389"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }
  security_rule {
    name                       = "OUTBOUND"
    priority                   = 4000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = var.global_tags
}
# Enable if troubleshooting is necessary out-of-band from Guacamole
# resource "azurerm_public_ip" "workload-pip" {
#   name                    = "${var.name_prefix}-workload-public-ip-${var.resource_tag}"
#   location                = var.location
#   resource_group_name     = var.resource_group
#   allocation_method       = "Static"
#   idle_timeout_in_minutes = 30

#   tags = var.global_tags
# }
resource "azurerm_network_interface" "lin-server-nic" {
  count                     = var.lin_vm_count
  name                      = "${var.name_prefix}-lin-server-${count.index + 1}-nic-${var.resource_tag}"
  location                  = var.location
  resource_group_name       = var.resource_group

  ip_configuration {
    name                          = "${var.name_prefix}-lin-server-${count.index + 1}-nic-conf-${var.resource_tag}"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    # Enable if troubleshooting is necessary out-of-band from Guacamole
    # public_ip_address_id          = azurerm_public_ip.workload-pip.id
  }
  
  dns_servers = ["8.8.8.8", "8.8.4.4"]
  #dns_servers = var.dns_servers
  
  tags = var.global_tags
}
resource "azurerm_network_interface_security_group_association" "lin-server-nic-association" {
  count                     = var.lin_vm_count
  network_interface_id      = azurerm_network_interface.lin-server-nic[count.index].id
  network_security_group_id = azurerm_network_security_group.lin-server-nsg[count.index].id
}
# Find Packer Image
data "azurerm_image" "search" {
  name                = var.workload_managed_vm_id
  resource_group_name = var.workload_managed_vm_rg
}
# Clone Packer VM image and apply to workload
resource "azurerm_virtual_machine" "lin-server-vm" {
  count                         = var.lin_vm_count
  name                          = "${var.name_prefix}-lin-server-vm-${count.index + 1}-${var.resource_tag}"
  location                      = var.location
  resource_group_name           = var.resource_group
  network_interface_ids         = [azurerm_network_interface.lin-server-nic[count.index].id]
  vm_size                       = var.instance_size
  delete_os_disk_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.search.id}"
  }

  storage_os_disk {
    name              = "${var.name_prefix}-lin-server-vm-${count.index + 1}-disk"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "${var.name_prefix}-lin-server-vm-${count.index + 1}-${var.resource_tag}"
    admin_username = "${var.vm_username}"
    admin_password = "${var.vm_password}"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = var.global_tags

  depends_on = [
    azurerm_network_interface.lin-server-nic,
    azurerm_network_interface_security_group_association.lin-server-nic-association
  ]
}