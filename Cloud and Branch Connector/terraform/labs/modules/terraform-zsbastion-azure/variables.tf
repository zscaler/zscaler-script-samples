variable "name_prefix" {
  description = "A prefix to associate to all the module resources"
  default     = "zs"
}

variable "resource_tag" {
  description = "A tag to associate to all the module resources"
  default     = "cloud-connector"
}

variable "deployment_tag" {
  description = "A deployment tag to associate to all the module resources"
  default     = "development"
}

variable "resource_group" {
  description = "Main Resource Group Name"
}

variable "public_subnet_id" {
  description = "The id of public subnet where the bastion host has to be attached"
}

variable "server_admin_username" {
  default   = "ubuntu"
  type      = string
}

# variable "user_data" {
#   description = "Cloud Init data"
# }

variable "ssh_key" {
  description = "SSH Key for instances"
}

variable "instance_size" {
  description = "The image size"
  default     = "Standard_B1s"
}

variable "instance_image_publisher" {
  description = "The image publisher"
  default     = "Canonical"
}

variable "instance_image_offer" {
  description = "The image offer"
  default     = "UbuntuServer"
}

variable "instance_image_sku" {
  description = "The image sku"
  default     = "18_04-lts-gen2"
}

variable "instance_image_version" {
  description = "The image version"
  default     = "latest"
}

variable "global_tags" {
  description = "populate custom user provided tags"
}

variable "location" {
  description = "Azure Region"
}
# variable "bastion_info" {
#   description = "A prefix to associate to all the module resources"
# }

variable "bastion_managed_vm_rg" {
  description = "The Azure Managed VM Image Resource Group"
  type        = string
}

variable "bastion_managed_vm_id" {
  description = "The Azure Managed VM Image Resource Group"
  type        = string
}

variable "vm_count" {
  description = "number of Workload VMs to deploy"
  type    = number
  default = 1
   validation {
          condition     = var.vm_count >= 1 && var.vm_count <= 250
          error_message = "Input vm_count must be a whole number between 1 and 9."
        }
}