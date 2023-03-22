data "azurerm_image" "search" {
  name                = var.bastion_managed_vm_id
  resource_group_name = var.bastion_managed_vm_rg
}

resource "azurerm_network_security_group" "bastion-nsg" {
  name                = "${var.name_prefix}-bastion-nsg-${var.resource_tag}"
  location            = var.location
  resource_group_name = var.resource_group

  security_rule {
    name                       = "SSH"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "22"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "WEB"
    priority                   = 4001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "8080"
    destination_address_prefix = "*"
  }
  security_rule {              
    name                       = "OUTBOUND"
    priority                   = 4002
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

  #   security_rule {
  #   name                       = "SSH-CC1"
  #   priority                   = 4001
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "2200"
  #   source_address_prefix      = "${chomp(var.bastion_info)}"
  #   destination_address_prefix = "*"
  # }
  #   security_rule {
  #   name                       = "SSH-CC2"
  #   priority                   = 4002
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "2201"
  #   source_address_prefix      = "${chomp(var.bastion_info)}"
  #   destination_address_prefix = "*"
  # }
  #   security_rule {
  #   name                       = "SSH-AC1"
  #   priority                   = 4003
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "2202"
  #   source_address_prefix      = "${chomp(var.bastion_info)}"
  #   destination_address_prefix = "*"
  # }
  #   security_rule {
  #   name                       = "SSH-AC2"
  #   priority                   = 4004
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "2203"
  #   source_address_prefix      = "${chomp(var.bastion_info)}"
  #   destination_address_prefix = "*"
  # }

  # tags = var.global_tags

resource "azurerm_public_ip" "bastion-pip" {
  name                    = "${var.name_prefix}-bastion-public-ip-${var.resource_tag}"
  location                = var.location
  resource_group_name     = var.resource_group
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30

  tags = var.global_tags
}

resource "azurerm_network_interface" "bastion-nic" {
  name                      = "${var.name_prefix}-bastion-nic-${var.resource_tag}"
  location                  = var.location
  resource_group_name       = var.resource_group

  ip_configuration {
    name                          = "${var.name_prefix}-bastion-nic-conf-${var.resource_tag}"
    subnet_id                     = var.public_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion-pip.id
  }

  tags = var.global_tags
}

resource "azurerm_network_interface_security_group_association" "bastion-nic-association" {
  network_interface_id      = azurerm_network_interface.bastion-nic.id
  network_security_group_id = azurerm_network_security_group.bastion-nsg.id
}

# Clone Packer VM image and apply to workload
resource "azurerm_virtual_machine" "bastion-vm" {
  count                         = var.vm_count
  name                          = "${var.name_prefix}-bastion-vm-${count.index + 1}-${var.resource_tag}"
  location                      = var.location
  resource_group_name           = var.resource_group
  network_interface_ids         = [azurerm_network_interface.bastion-nic.id]
  vm_size                       = var.instance_size
  delete_os_disk_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.search.id}"
  }

  storage_os_disk {
    name              = "${var.name_prefix}-bastion-vm-${count.index + 1}-disk"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "${var.name_prefix}-bastion-vm-${count.index + 1}-${var.resource_tag}"
    admin_username = "ubuntu"
    admin_password = "CloudConnector2022!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = var.global_tags

  depends_on = [
    azurerm_network_interface.bastion-nic,
    azurerm_network_interface_security_group_association.bastion-nic-association
  ]
}

# resource "azurerm_linux_virtual_machine" "bastion-vm" {
#   name                         = "${var.name_prefix}-bastion-vm-${var.resource_tag}"
#   location                     = var.location
#   resource_group_name          = var.resource_group
#   network_interface_ids        = [azurerm_network_interface.bastion-nic.id]
#   size                         = var.instance_size
#   admin_username               = var.server_admin_username
#   computer_name                = "${var.name_prefix}-bastion-${var.resource_tag}"
#   custom_data                  = base64encode(var.user_data)
#   admin_ssh_key {
#     username   = var.server_admin_username
#     public_key = "${trimspace(var.ssh_key)} ${var.server_admin_username}@me.io"
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Premium_LRS"
#   }

#   source_image_reference {
#     publisher = var.instance_image_publisher
#     offer     = var.instance_image_offer
#     sku       = var.instance_image_sku
#     version   = var.instance_image_version
#   }

#   tags = var.global_tags

#   depends_on = [
#     azurerm_network_interface.bastion-nic,
#     azurerm_network_interface_security_group_association.bastion-nic-association
#   ]
# }