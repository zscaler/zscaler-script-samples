data "azurerm_subscription" "current-subscription" {}

data "azurerm_user_assigned_identity" "selected" {
  name                = var.cc_vm_managed_identity_name
  resource_group_name = var.cc_vm_managed_identity_resource_group
}


# Create NSGs to be assigned to CC management interfaces
resource "azurerm_network_security_group" "cc-mgmt-nsg" {
  count               = var.cc_count
  name                = "${var.name_prefix}-ccvm-${count.index + 1}-mgmt-nsg-${var.resource_tag}"
  location            = var.location
  resource_group_name = var.resource_group

  security_rule {
    name                       = "SSH_BASTION"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }
  #   security_rule {
  #   name                       = "SSH_BASTION_PRIV"
  #   priority                   = 4001
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "22"
  #   source_address_prefix      = "${var.bastion_priv_info}"
  #   destination_address_prefix = "*"
  # }

  security_rule {
    name                       = "ICMP_VNET"
    priority                   = 4002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

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


# Create NSGS to be assigned to CC service interfaces
resource "azurerm_network_security_group" "cc-service-nsg" {
  count               = var.cc_count
  name                = "${var.name_prefix}-ccvm-${count.index + 1}-service-nsg-${var.resource_tag}"
  location            = var.location
  resource_group_name = var.resource_group
  
  security_rule {
    name                       = "ALL_VNET"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"  
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

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

# Cretae CC management interfaces
resource "azurerm_network_interface" "cc-mgmt-nic" {
  count                     = var.cc_count
  name                      = "${var.name_prefix}-ccvm-${count.index + 1}-mgmt-nic-${var.resource_tag}"
  location                  = var.location
  resource_group_name       = var.resource_group

  ip_configuration {
    name                          = "${var.name_prefix}-cc-mgmt-nic-conf-${var.resource_tag}"
    subnet_id                     = element(var.mgmt_subnet_id, count.index)
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }

  tags = var.global_tags
}


# Associate CC management NSGs to management interfaces
resource "azurerm_network_interface_security_group_association" "ec-mgmt-nic-association" {
  count                     = var.cc_count
  network_interface_id      = azurerm_network_interface.cc-mgmt-nic[count.index].id
  network_security_group_id = azurerm_network_security_group.cc-mgmt-nsg[count.index].id
}


# Cretae CC primary service interfaces
resource "azurerm_network_interface" "cc-service-nic" {
  count                     = var.cc_count
  name                      = "${var.name_prefix}-ccvm-${count.index + 1}-service-nic-${var.resource_tag}"
  location                  = var.location
  resource_group_name       = var.resource_group
  enable_ip_forwarding      = true

  ip_configuration {
    name                          = "${var.name_prefix}-cc-service-nic-conf-${var.resource_tag}"
    subnet_id                     = element(var.service_subnet_id, count.index)
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }

  tags = var.global_tags

  depends_on = [azurerm_network_interface.cc-mgmt-nic]
}


# Associate CC service NSGs to service interfaces
resource "azurerm_network_interface_security_group_association" "ec-service-nic-association" {
  count                     = var.cc_count
  network_interface_id      = azurerm_network_interface.cc-service-nic[count.index].id
  network_security_group_id = azurerm_network_security_group.cc-service-nsg[count.index].id
}


# If enabled, associate all CC primary service interfaces to LB backend address pool
resource "azurerm_network_interface_backend_address_pool_association" "cc-vm-service-nic-lb-association" {
  count                   = var.lb_association_enabled  == true ? var.cc_count : 0
  network_interface_id    = azurerm_network_interface.cc-service-nic[count.index].id
  ip_configuration_name   = "${var.name_prefix}-cc-service-nic-conf-${var.resource_tag}"
  backend_address_pool_id = var.backend_address_pool
}


# Create CC virtual appliance
resource "azurerm_linux_virtual_machine" "cc-vm" {
  count                        = var.cc_count
  name                         = "${var.name_prefix}-ccvm-${count.index + 1}-${var.resource_tag}"
  location                     = var.location
  resource_group_name          = var.resource_group
  size                         = var.ccvm_instance_type
  availability_set_id          = local.zones_supported == false ? azurerm_availability_set.cc-availability-set.*.id[0] : null
  zone                         = local.zones_supported ? element(var.zones, count.index) : null

  # Cloud Connector requires that the ordering of network_interface_ids associated are #1/mgmt, #2/service-1(primary)
  network_interface_ids        = [
    azurerm_network_interface.cc-mgmt-nic[count.index].id,
    azurerm_network_interface.cc-service-nic[count.index].id
  ]

  computer_name                = "${var.name_prefix}-ccvm-${count.index + 1}-${var.resource_tag}"
  admin_username               = var.cc_username
  custom_data                  = base64encode(var.user_data)

  admin_ssh_key {
    username   = var.cc_username
    public_key = "${trimspace(var.ssh_key)} ${var.cc_username}@me.io"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = var.ccvm_image_publisher
    offer     = var.ccvm_image_offer
    sku       = var.ccvm_image_sku
    version   = var.ccvm_image_version
  }

  plan {
    publisher = var.ccvm_image_publisher
    name      = var.ccvm_image_sku
    product   = var.ccvm_image_offer
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.selected.id]
  }

  tags = var.global_tags

  depends_on = [
    azurerm_network_interface_security_group_association.ec-mgmt-nic-association,
    azurerm_network_interface_security_group_association.ec-service-nic-association
  ]
}


# If CC zones are not manually defined, create availability set
resource "azurerm_availability_set" "cc-availability-set" {
  count                        = local.zones_supported == false ? 1 : 0
  name                         = "${var.name_prefix}-ccvm-availability-set-${var.resource_tag}"
  location                     = var.location
  resource_group_name          = var.resource_group
  platform_fault_domain_count  = local.max_fd_supported == true ? 3 : 2
  
  tags                         = var.global_tags
}
