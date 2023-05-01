variable "name_prefix" {
  description = "A prefix to associate to all the Cloud Connector module resources"
  default     = "zscaler-cc"
}

variable "resource_tag" {
  description = "A tag to associate to all the Cloud Connector module resources"
  default     = "cloud-connector"
}

variable "vpc" {
  description = "VPC id for the Route53 Endpoint"
}

variable "r53_subnet_ids" {
  description = "Subnet IDs for the Route53 Endpoint"
}

variable "domain_names" {
  description = "The domain name that requires forwarding to a custom DNS server"
}

variable "target_address" {
  description = "DNS queries will be forwarded to this IPv4 addresse"
  default     = "8.8.8.8"
}

variable "global_tags" {
  description = "populate custom user provided tags"
}
