# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.name_prefix}-RG-${var.name_suffix}"
  location = var.azure_region
  
  tags = local.global_tags
}

#Create the CC Managed Identity and assign Network Contributor role
resource "azurerm_user_assigned_identity" "cc-mi" {
  location = var.azure_region
  name = "${var.name_prefix}-MI-${var.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "cc-role" {
  principal_id = azurerm_user_assigned_identity.cc-mi.principal_id
  scope = azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
}

#Create KeyVault, assign new Managed Identity, allow Service Principal access and set Secrets
resource "azurerm_key_vault" "keyvault" {
  name                       = "${var.name_prefix}-KV-${var.name_suffix}"
  location                   = var.azure_region
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = var.tenant_id
  enabled_for_template_deployment = true
  sku_name                   = "standard"
}

resource "azurerm_key_vault_access_policy" "terraform_sp_access" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = var.tenant_id
  object_id    = var.object_id

  secret_permissions = [
    "Get", "List", "Purge", "Delete", "Recover", "Backup", "Restore", "Set",
  ]
}
resource "azurerm_key_vault_access_policy" "cc-access" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = azurerm_user_assigned_identity.cc-mi.tenant_id
  object_id    = azurerm_user_assigned_identity.cc-mi.principal_id

  secret_permissions = [
    "Get", "List",
  ]
}

resource "azurerm_key_vault_secret" "username" {
  name         = "username"
  value        = "${var.secret_username}"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_sp_access
  ]
}

resource "azurerm_key_vault_secret" "password" {
  name         = "password"
  value        = "${var.secret_password}"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_sp_access
  ]
}

resource "azurerm_key_vault_secret" "apikey" {
  name         = "api-key"
  value        = "${var.secret_apikey}"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_sp_access
  ]
}

# Map default tags with values to be assigned to all tagged resources
locals {
  global_tags = {
  Owner       = var.owner_tag
  ManagedBy   = "terraform"
  Vendor      = "Zscaler"
  Environment = var.environment
  }
}

############################################################################################################################
#### The following lines generates a new SSH key pair and stores the PEM file locally. The public key output is used    ####
#### as the ssh_key passed variable to the cc_vm module for admin_ssh_key public_key authentication                     ####
#### This is not recommended for production deployments. Please consider modifying to pass your own custom              ####
#### public key file located in a secure location                                                                       ####
############################################################################################################################
# private key for login
resource "tls_private_key" "key" {
  algorithm   = var.tls_key_algorithm
}

# save the private key
resource "null_resource" "save-key" {
  triggers = {
    key = tls_private_key.key.private_key_pem
  }

  provisioner "local-exec" {
    command = <<EOF
      echo "${tls_private_key.key.private_key_pem}" > ${var.name_prefix}-azure-key-${var.name_suffix}.pem
      chmod 0600 ${var.name_prefix}-azure-key-${var.name_suffix}.pem
EOF
  }
}

###########################################################################################################################
###########################################################################################################################

## Create the user_data file
locals {
  userdata = <<USERDATA
[ZSCALER]
CC_URL=${var.azure_cc_vm_prov_url}
AZURE_VAULT_URL=${azurerm_key_vault.keyvault.vault_uri}
HTTP_PROBE_PORT=${var.http_probe_port}
USERDATA
}

resource "local_file" "user-data-file" {
  content  = local.userdata
  filename = "cc_user_data.txt"
}

# 1. Network Infra
## Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.name_prefix}-vnet-${var.name_suffix}"
  address_space       = [var.network_address_space]
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  
  tags = local.global_tags
}

resource "azurerm_virtual_network_dns_servers" "dns" {
  virtual_network_id = azurerm_virtual_network.vnet.id
  dns_servers        = ["8.8.8.8", "8.8.4.4", "4.2.2.2", "4.2.2.1"]
}

# Create Bastion Host public subnet
resource "azurerm_subnet" "bastion-subnet" {
 name                 = "${var.name_prefix}-bastion-subnet-${var.name_suffix}"
 resource_group_name  = azurerm_resource_group.main.name
 virtual_network_name = azurerm_virtual_network.vnet.name
 address_prefixes     = [cidrsubnet(var.network_address_space, 8, 101)]
}

# Create Workload Subnet
resource "azurerm_subnet" "workload-subnet" {
  name                 = "${var.name_prefix}-workload-subnet-${var.name_suffix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [cidrsubnet(var.network_address_space, 8, 1)]
}

# Create Public IPs for NAT Gateways
resource "azurerm_public_ip" "nat-pip" {
  count                   = var.zones_enabled == true ? length(distinct(var.zones)) : 1
  name                    = "${var.name_prefix}-nat-gw-public-ip-${count.index + 1}-${var.name_suffix}"
  location                = var.azure_region
  resource_group_name     = azurerm_resource_group.main.name
  allocation_method       = "Static"
  sku                     = "Standard"
  idle_timeout_in_minutes = 30
  zones                   = local.zones_supported ? [element(var.zones, count.index)] : null

  tags = local.global_tags
}

# Create NAT Gateways
resource "azurerm_nat_gateway" "nat-gw" {
  count                   = var.zones_enabled == true ? length(distinct(var.zones)) : 1
  name                    = "${var.name_prefix}-nat-gw-${count.index + 1}-${var.name_suffix}"
  location                = var.azure_region
  resource_group_name     = azurerm_resource_group.main.name
  idle_timeout_in_minutes = 10
  zones                   = local.zones_supported ? [element(var.zones, count.index)] : null
  
  tags = local.global_tags
}

# Associate Public IP to NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "nat-gw-association1" {
  count                = length(azurerm_nat_gateway.nat-gw.*.id)
  nat_gateway_id       = azurerm_nat_gateway.nat-gw.*.id[count.index]
  public_ip_address_id = azurerm_public_ip.nat-pip.*.id[count.index]

  depends_on = [
    azurerm_public_ip.nat-pip,
    azurerm_nat_gateway.nat-gw
  ]
}

# ## 2. Create Bastion Host
# module "bastion" {
#  source             = "../modules/terraform-zsbastion-azure"
#  location           = var.azure_region
#  name_prefix        = var.name_prefix
#  resource_tag       = var.name_suffix
#  global_tags        = local.global_tags
#  resource_group     = azurerm_resource_group.main.name
#  public_subnet_id   = azurerm_subnet.bastion-subnet.id
#  ssh_key            = tls_private_key.key.public_key_openssh
#  bastion_info       = data.local_file.bastion-info.content
#  user_data          = local.bastionuserdata
# }
## 2. Create Guacamole Host
module "bastion" {
 source             = "../modules/terraform-zsbastion-azure"
 location           = var.azure_region
 name_prefix        = var.name_prefix
 resource_tag       = var.name_suffix
 global_tags        = local.global_tags
 resource_group     = azurerm_resource_group.main.name
 public_subnet_id   = azurerm_subnet.bastion-subnet.id
 ssh_key            = tls_private_key.key.public_key_openssh
 # bastion_info       = data.local_file.bastion-info.content
 # user_data          = local.bastionuserdata
 bastion_managed_vm_rg      = var.bastion_managed_vm_rg
 bastion_managed_vm_id      = var.bastion_managed_vm_id
}

# 3. Create Windows Workloads
module "workload" {
  source             = "../modules/terraform-zsworkload-win-azure"
  win_vm_count       = var.win_vm_count
  location           = var.azure_region
  name_prefix        = var.name_prefix
  name_suffix        = var.name_suffix
  resource_tag       = var.name_suffix
  global_tags        = local.global_tags
  resource_group     = azurerm_resource_group.main.name
  subnet_id          = azurerm_subnet.workload-subnet.id
  ssh_key            = tls_private_key.key.public_key_openssh
  # bastion_info       = data.local_file.bastion-info.content
  # user_data          = local.workloaduserdata
  dns_servers        = ["8.8.8.8","8.8.4.4"]
  vm_username        = var.vm_username
  vm_password        = var.vm_password
}
# Create Linux Workloads
module "workload-lin" {
  source             = "../modules/terraform-zsworkload-linux-azure"
  lin_vm_count       = var.lin_vm_count
  location           = var.azure_region
  name_prefix        = var.name_prefix
  name_suffix        = var.name_suffix
  resource_tag       = var.name_suffix
  global_tags        = local.global_tags
  resource_group     = azurerm_resource_group.main.name
  subnet_id          = azurerm_subnet.workload-subnet.id
  ssh_key            = tls_private_key.key.public_key_openssh
  # bastion_info       = data.local_file.bastion-info.content
  # user_data          = local.workloaduserdata
  dns_servers        = ["8.8.8.8","8.8.4.4"]
  vm_username        = var.vm_username
  vm_password        = var.vm_password
  workload_managed_vm_id = var.workload_managed_vm_id
  workload_managed_vm_rg = var.workload_managed_vm_rg
}

# 4. Create CC network, routing, and appliance
# Create Cloud Connector Subnets
resource "azurerm_subnet" "cc-subnet" {
  count                = var.zones_enabled == true ? length(distinct(var.zones)) : 1
  name                 = "${var.name_prefix}-cc-subnet-${count.index + 1}-${var.name_suffix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.cc_subnets != null ? [element(var.cc_subnets, count.index)] : [cidrsubnet(var.network_address_space, 8, count.index + 200)]
}

# Associate Cloud Connector Subnet to NAT Gateway
resource "azurerm_subnet_nat_gateway_association" "subnet-nat-association-ec" {
  count          = length(azurerm_subnet.cc-subnet.*.id)
  subnet_id      = azurerm_subnet.cc-subnet.*.id[count.index]
  nat_gateway_id = azurerm_nat_gateway.nat-gw.*.id[count.index]

  depends_on = [
    azurerm_subnet.cc-subnet,
    azurerm_nat_gateway.nat-gw
  ]
}

# Cloud Connector Module variables
# Create X CC VMs per cc_count by default in an availability set for Azure data center fault tolerance.
# Optionally create X CC VMs per cc_count which will span equally across designated availability zones specified in zones_enables
# zones variables.
# E.g. cc_count set to 4 and 2 zones ['1","2"] will create 2x CCs in AZ1 and 2x CCs in AZ2
module "cc-vm" {
  count                                 = var.zones_enabled == true ? 1 : 0
  cc_count                              = var.cc_count
  source                                = "../modules/terraform-zscc-azure"
  name_prefix                           = var.name_prefix
  resource_tag                          = var.name_suffix
  global_tags                           = local.global_tags
  resource_group                        = azurerm_resource_group.main.name
  mgmt_subnet_id                        = azurerm_subnet.cc-subnet.*.id
  service_subnet_id                     = azurerm_subnet.cc-subnet.*.id
  ssh_key                               = tls_private_key.key.public_key_openssh
  cc_vm_managed_identity_name           = azurerm_user_assigned_identity.cc-mi.name
  cc_vm_managed_identity_resource_group = azurerm_resource_group.main.name
  user_data                             = local.userdata
  backend_address_pool                  = module.cc-lb[0].lb_backend_address_pool
  lb_association_enabled                = true
  location                              = var.azure_region
  zones_enabled                         = var.zones_enabled
  zones                                 = var.zones
  ccvm_instance_type                    = var.ccvm_instance_type
  ccvm_image_publisher                  = var.ccvm_image_publisher
  ccvm_image_offer                      = var.ccvm_image_offer
  ccvm_image_sku                        = var.ccvm_image_sku
  ccvm_image_version                    = var.ccvm_image_version
  # bastion_info                          = data.local_file.bastion-info.content
  # bastion_priv_info                     = module.bastion.private_ip

  depends_on = [
    azurerm_subnet_nat_gateway_association.subnet-nat-association-ec,
    local_file.user-data-file,
  ]
}
module "cc-vm-nozone" {
  count                                 = var.zones_enabled == false ? 1 : 0
  cc_count                              = var.cc_count
  source                                = "../modules/terraform-zscc-azure"
  name_prefix                           = var.name_prefix
  resource_tag                          = var.name_suffix
  global_tags                           = local.global_tags
  resource_group                        = azurerm_resource_group.main.name
  mgmt_subnet_id                        = azurerm_subnet.cc-subnet.*.id
  service_subnet_id                     = azurerm_subnet.cc-subnet.*.id
  ssh_key                               = tls_private_key.key.public_key_openssh
  cc_vm_managed_identity_name           = azurerm_user_assigned_identity.cc-mi.name
  cc_vm_managed_identity_resource_group = azurerm_resource_group.main.name
  user_data                             = local.userdata
  backend_address_pool                  = module.cc-lb-nozone[0].lb_backend_address_pool
  lb_association_enabled                = true
  location                              = var.azure_region
  zones_enabled                         = var.zones_enabled
  zones                                 = var.zones
  ccvm_instance_type                    = var.ccvm_instance_type
  ccvm_image_publisher                  = var.ccvm_image_publisher
  ccvm_image_offer                      = var.ccvm_image_offer
  ccvm_image_sku                        = var.ccvm_image_sku
  ccvm_image_version                    = var.ccvm_image_version
  # bastion_info                          = data.local_file.bastion-info.content
  # bastion_priv_info                     = module.bastion.private_ip

  depends_on = [
    azurerm_subnet_nat_gateway_association.subnet-nat-association-ec,
    local_file.user-data-file,
  ]
}

# Azure Load Balancer Module variables
module "cc-lb" {
  count                                 = var.zones_enabled == true ? 1 : 0
  source                                = "../modules/terraform-zslb-azure"
  name_prefix                           = var.name_prefix
  resource_tag                          = var.name_suffix
  global_tags                           = local.global_tags
  resource_group                        = azurerm_resource_group.main.name
  location                              = var.azure_region
  subnet_id                             = azurerm_subnet.cc-subnet.*.id[0]
  http_probe_port                       = var.http_probe_port
  load_distribution                     = "SourceIP"
}

module "cc-lb-nozone" {
  count                                 = var.zones_enabled == false ? 1 : 0
  source                                = "../modules/terraform-zslb-nozone-azure"
  name_prefix                           = var.name_prefix
  resource_tag                          = var.name_suffix
  global_tags                           = local.global_tags
  resource_group                        = azurerm_resource_group.main.name
  location                              = var.azure_region
  subnet_id                             = azurerm_subnet.cc-subnet.*.id[0]
  http_probe_port                       = var.http_probe_port
  load_distribution                     = "SourceIP"
}

# Create Workload Route Table to send to Cloud Connector LB
resource "azurerm_route_table" "workload-rt" {
  count               = var.zones_enabled == true ? 1 : 0
  name                = "${var.name_prefix}-workload-rt-${var.name_suffix}"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name

  disable_bgp_route_propagation = true

  route {
    name                   = "default-to-internet"
    address_prefix         = "0.0.0.0/0"
    # next_hop_type          = "Internet"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.cc-lb[0].lb_ip
  }
  # Enable when troubleshooting out-of-band from Guacamole
  # route {
  #   name                   = "temp"
  #   address_prefix         = "104.129.205.36/32"
  #   next_hop_type          = "Internet"
  #   # next_hop_type          = "VirtualAppliance"
  #   # next_hop_in_ip_address = module.cc-lb-nozone[0].lb_ip
  # }
}

resource "azurerm_route_table" "workload-rt-nozone" {
  count               = var.zones_enabled == false ? 1 : 0
  name                = "${var.name_prefix}-workload-rt-${var.name_suffix}"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name

  disable_bgp_route_propagation = true

  route {
    name                   = "default-to-internet"
    address_prefix         = "0.0.0.0/0"
    # next_hop_type          = "Internet"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.cc-lb-nozone[0].lb_ip
  }
  route {
    name                   = "temp"
    address_prefix         = "104.129.205.36/32"
    next_hop_type          = "Internet"
    # next_hop_type          = "VirtualAppliance"
    # next_hop_in_ip_address = module.cc-lb-nozone[0].lb_ip
  }
}

# Associate Route Table with Workload Subnet
resource "azurerm_subnet_route_table_association" "server-rt-assoc" {
  count          = var.zones_enabled == true ? 1 : 0
  subnet_id      = azurerm_subnet.workload-subnet.id
  route_table_id = azurerm_route_table.workload-rt[0].id
}

# Associate Route Table with Workload Subnet
resource "azurerm_subnet_route_table_association" "server-rt-assoc-nozone" {
  count          = var.zones_enabled == false ? 1 : 0
  subnet_id      = azurerm_subnet.workload-subnet.id
  route_table_id = azurerm_route_table.workload-rt-nozone[0].id
}

# Create CC Route Table to send to Internet
resource "azurerm_route_table" "cc-rt" {
  name                = "${var.name_prefix}-cc-rt-${var.name_suffix}"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name

  disable_bgp_route_propagation = true

  route {
    name                   = "default-to-internet"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "Internet"

  }
}

# Associate Route Table with CC Subnet
resource "azurerm_subnet_route_table_association" "cc-rt-assoc" {
  count          = length(azurerm_subnet.cc-subnet.*.id)
  subnet_id      = azurerm_subnet.cc-subnet.*.id[count.index]
  route_table_id = azurerm_route_table.cc-rt.id
}

# Copy User Mapping file to Guacamole
resource "null_resource" "user-mapping" {
  provisioner "file" {
    source      = "user-mapping.xml"
    destination = "/home/ubuntu/user-mapping.xml"
  }
  connection {
    type     = "ssh"
    host     = chomp(module.bastion.public_ip)
    user     = "ubuntu"
    password = "CloudConnector2022!"
  }
  depends_on = [local_file.user-mapping]
}
resource "null_resource" "file-move" {
  provisioner "remote-exec" {
    inline = [
      "sudo cp user-mapping.xml /etc/guacamole/user-mapping.xml"
    ]
  }
  connection {
    type     = "ssh"
    host     = chomp(module.bastion.public_ip)
    user     = "ubuntu"
    password = "CloudConnector2022!"
  }
  depends_on = [local_file.user-mapping]
}