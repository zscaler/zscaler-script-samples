variable "name_prefix" {
  description = "A prefix to associate to all the module resources"
  default     = "zscc"
}
variable "name_suffix" {
  description = "A suffix to associate to all the module resources"
}

variable "disk_size" {
  description = "The size of the root volume in gigabytes."
  default     = 30
}

variable "resource_tag" {
  description = "A tag to associate to all the module resources"
  default     = "cloud-connector"
}

variable "vpc" {
  description = "Main VPC"
}

variable "subnet" {
  description = "The private subnet where the server has to be attached"
}

variable "instance_type" {
  description = "The server instance type"
  default     = "t3.medium"
}

variable "instance_key" {
  description = "SSH Key for instances"
}

variable "workload_count" {
  description = "number of workloads to deploy"
  type = number
  default = 2
}

variable "pem_output" {
  description = "SSH Key for instances"
}

variable "global_tags" {
  description = "populate custom user provided tags"
}