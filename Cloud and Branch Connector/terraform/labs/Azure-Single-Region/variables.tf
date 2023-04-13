variable "cloudname" {
  description = "Zscaler Cloud Name"
  default = "zscalertwo.net"
}
# Azure variables
variable "secret_username" {
  description = "Azure KeyVault Username for Cloud Connector provisioning"
  type        = string
}
variable "secret_password" {
  description = "Azure KeyVault Password for Cloud Connector provisioning"
  type        = string
}
variable "secret_apikey" {
  description = "Azure KeyVault API Key for Cloud Connector provisioning"
  type        = string
}

variable "azure_region" {
  description = "The Azure Region"
}

variable "bastion_managed_vm_rg" {
  description = "The Azure Managed VM Image Resource Group"
  type        = string
}

variable "bastion_managed_vm_id" {
  description = "The Azure Managed VM Image ID"
  type        = string
}

variable "workload_managed_vm_rg" {
  description = "The Azure Managed Workload Resource Group"
  type        = string
}

variable "workload_managed_vm_id" {
  description = "The Azure Managed Workload ID"
  type        = string
}

variable "name_prefix" {
  description = "The name prefix for all resources"
  default     = "zscc"
  type        = string
}

variable "name_suffix" {
  description = "The name suffix for all your resources"
  type        = string
}

variable "network_address_space" {
  description = "The prefix for VNet(s)"
  default     = "10.1.0.0/16"
}

variable "cc_subnets" {
  description = "Cloud Connector Subnets"
  default     = null
  type        = list(string)
}

variable "environment" {
  description = "Environment"
  default     = "Development"
}

variable "server_admin_username" {
  description = "Username for Linux workload(s)"
  default   = "ubuntu"
  type      = string
}

variable "tls_key_algorithm" {
  default   = "RSA"
  type      = string
}

variable "azure_cc_vm_prov_url" {
  description = "Zscaler Cloud Connector Provisioning URL"
  type        = string
}

variable "ccvm_image_publisher" {
  description = "Azure Marketplace Cloud Connector Image Publisher"
  default     = "zscaler1579058425289"
}

variable "ccvm_image_offer" {
  description = "Azure Marketplace Cloud Connector Image Offer"
  default     = "zia_cloud_connector"
}

variable "ccvm_image_sku" {
  description = "Azure Marketplace Cloud Connector Image SKU"
  default     = "zs_ser_gen1_cc_01"
}

variable "ccvm_image_version" {
  description = "Azure Marketplace Cloud Connector Image Version"
  default     = "latest"
}

variable "ccvm_instance_type" {
  description = "Cloud Connector Instance Type (Standard D2s v3 is recommended)"
  default     = "Standard_D2s_v3"
  validation {
          condition     = ( 
            var.ccvm_instance_type == "Standard_D2s_v3"  ||
            var.ccvm_instance_type == "Standard_DS3_v2"
          )
          error_message = "Input ccvm_instance_type must be set to an approved vm size."
      }
}

variable "http_probe_port" {
  description = "The port Cloud Connector will listen on for Load Balancer Healthchecks"
  default = 0
  validation {
          condition     = (
            var.http_probe_port == 0 ||
            var.http_probe_port == 80 ||
          ( var.http_probe_port >= 1024 && var.http_probe_port <= 65535 )
        )
          error_message = "Input http_probe_port must be set to a single value of 80 or any number between 1024-65535."
      }
}

variable "cross_zone_lb_enabled" {
  default = true
  type = bool
  description = "Toggle cross-zone loadbalancing of GWLB on/off"
}

variable "lin_vm_count" {
  description = "Number of Linux workload VMs to deploy"
  type    = number
  default = 1
   validation {
          condition     = var.lin_vm_count >= 1 && var.lin_vm_count <= 250
          error_message = "Input vm_count must be a whole number between 1 and 9."
        }
}
variable "win_vm_count" {
  description = "Number of Windows workload VMs to deploy"
  type    = number
  default = 1
   validation {
          condition     = var.win_vm_count >= 1 && var.win_vm_count <= 250
          error_message = "Input vm_count must be a whole number between 1 and 9."
        }
}

variable "cc_count" {
  description = "Number of Cloud Connector appliances to create"
  type    = number
  default = 2
   validation {
          condition     = var.cc_count >= 1 && var.cc_count <= 250
          error_message = "Input cc_count must be a whole number between 1 and 250."
        }
}

# Validation to determine if Azure Region selected supports availabilty zones if desired
locals {
  az_supported_regions = ["australiaeast","brazilsouth","canadacentral","centralindia","centralus","eastasia","eastus","eastus2","francecentral","germanywestcentral","japaneast","koreacentral","northeurope","norwayeast","southafricanorth","southcentralus","southeastasia","swedencentral","uksouth","westeurope","westus2"]
  zones_supported = (
    contains(local.az_supported_regions, var.azure_region) && var.zones_enabled == true
  )
}

variable "zones_enabled" {
  type        = bool
  default     = false  
  description = "Enable/Disable Zones"
}

variable "zones" {
  type        = list(string)
  default     = ["1"]
  description = "Selected Zones"
  validation {
          condition     = (
            !contains([for zones in var.zones: contains( ["1", "2", "3"], zones)], false)
          )
          error_message = "Input zones variable must be a number 1-3."
      }
}

variable "owner_tag" {
  description = "Custom owner tag attributes"
  type = string
  default = "zscc-admin"
}

variable "subscription_id" {
  description = "Azure Subscription ID"
}
variable "client_id" {
  description = "Azure Client ID"
}
variable "client_secret" {
  description = "Azure Client Secret"
}
variable "tenant_id" {
  description = "Azure Tenant ID"
}
variable "object_id" {
  description = "Azure Object ID"
}
variable "vm_username" {
  description = "Username for workload(s)"
}
variable "vm_password" {
  description = "Password for workload(s)"
}