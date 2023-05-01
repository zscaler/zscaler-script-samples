# AWS variables
variable "aws_region" {
  default = "us-east-2"
  description = "The AWS Region"
}

variable "name_prefix" {
  description = "The prefix for all your resources"
  default     = "zscc"
  type        = string
}

variable "name_suffix" {
  description = "The suffix for all your resources"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  default     = "10.1.0.0/16"
}

variable "workload_count" {
  description = "Default number of workload VMs to create"
  default     = 1
}

variable "az_count" {
  description = "Default number of subnets to create based on availability zone"
  type = number
  default     = 1
  validation {
          condition     = (
          (var.az_count >= 1 && var.az_count <= 3)
        )
          error_message = "Input az_count must be set to a single value between 1 and 3. Note* some regions have greater than 3 AZs. Please modify az_count validation in variables.tf if you are utilizing more than 3 AZs in a region that supports it. https://aws.amazon.com/about-aws/global-infrastructure/regions_az/."
      }
}

variable "aws_access_key" {
  description = "AWS Access Key"
  type = string
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type = string
}

variable "owner_tag" {
  description = "populate custom owner tag attribute"
  type = string
  default = "otto"
}

variable "tls_key_algorithm" {
  default   = "RSA"
  type      = string
}