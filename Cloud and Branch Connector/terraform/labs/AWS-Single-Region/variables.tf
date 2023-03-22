variable "cloudname" {
  description = "Zscaler Cloud Name"
  default = "zscalertwo.net"
}
# AWS variables
variable "aws_region1" {
  description = "The first AWS Region"
  default = "us-east-2"
}

variable "name_prefix" {
  description = "The prefix for all resources"
  default     = "zscc"
  type        = string
}

variable "name_suffix" {
  description = "The suffix for all your resources"
  type        = string
}

variable "vpc_cidr" {
  description = "The prefix for VPCs"
  default     = "10.1.0.0/16"
}

variable "cc_count" {
  description = "Number of Cloud Connector appliances to create"
  default     = 2
}

variable "az_count" {
  description = "Number of subnets to create based on availability zone"
  type = number
  default     = 1
  validation {
          condition     = (
          (var.az_count >= 1 && var.az_count <= 3)
        )
          error_message = "Input az_count must be set to a single value between 1 and 3. Note* some regions have greater than 3 AZs. Please modify az_count validation in variables.tf if you are utilizing more than 3 AZs in a region that supports it. https://aws.amazon.com/about-aws/global-infrastructure/regions_az/."
      }
}

variable "http_probe_port" {
  description = "The port Cloud Connector will listen on for Load Balancer Healthchecks"
  default = 10000
  validation {
          condition     = (
            var.http_probe_port == 0 ||
            var.http_probe_port == 80 ||
          ( var.http_probe_port >= 1024 && var.http_probe_port <= 65535 )
        )
          error_message = "Input http_probe_port must be set to a single value of 80 or any number between 1024-65535."
      }
}

variable "cc_vm_prov_url" {
  description = "Zscaler Cloud Connector Provisioning URL"
  type        = string
}

variable "secret_username" {
  description = "AWS Secrets Manager Username for Cloud Connector provisioning"
  type        = string
}
variable "secret_password" {
  description = "AWS Secrets Manager Password for Cloud Connector provisioning"
  type        = string
}
variable "secret_apikey" {
  description = "AWS Secrets Manager API Key for Cloud Connector provisioning"
  type        = string
}

variable "ccvm_instance_type" {
  description = "Cloud Connector Instance Type (M5.large is recommended)"
  default     = "m5.large"
  validation {
          condition     = ( 
            var.ccvm_instance_type == "t3.medium"  ||
            var.ccvm_instance_type == "m5.large"   ||
            var.ccvm_instance_type == "c5.large"   ||
            var.ccvm_instance_type == "c5a.large"  ||
            var.ccvm_instance_type == "m5.2xlarge" ||
            var.ccvm_instance_type == "c5.2xlarge" ||
            var.ccvm_instance_type == "m5.4xlarge" ||
            var.ccvm_instance_type == "c5.4xlarge"
          )
          error_message = "Input ccvm_instance_type must be set to an approved vm instance type."
      }
}

variable "owner_tag" {
  description = "Custom owner tag attributes"
  type = string
  default = "EaaS"
}

variable "tls_key_algorithm" {
  default   = "RSA"
  type      = string
}

variable "cc_instance_size" {
  description = "Zscaler Cloud Connector instance size (Small is recommended)"
  default = "small"
   validation {
          condition     = ( 
            var.cc_instance_size == "small"  ||
            var.cc_instance_size == "medium" ||
            var.cc_instance_size == "large"
          )
          error_message = "Input cc_instance_size must be set to an approved cc instance type."
      }
}

locals {
  small_cc_instance  = ["t3.medium","m5.large","c5.large","c5a.large","m5.2xlarge","c5.2xlarge","m5.4xlarge","c5.4xlarge"]
  medium_cc_instance = ["m5.2xlarge","c5.2xlarge","m5.4xlarge","c5.4xlarge"]
  large_cc_instance  = ["m5.4xlarge","c5.4xlarge"]
  
  valid_cc_create = (
contains(local.small_cc_instance, var.ccvm_instance_type) && var.cc_instance_size == "small"   ||
contains(local.medium_cc_instance, var.ccvm_instance_type) && var.cc_instance_size == "medium" ||
contains(local.large_cc_instance, var.ccvm_instance_type) && var.cc_instance_size == "large"
 )
}

variable "aws_access_key" {
  description = "AWS Access Key"
  type = string
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type = string
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

variable "vm_username" {
  description = "Username for workload(s)"
}
variable "vm_password" {
  description = "Password for workload(s)"
}