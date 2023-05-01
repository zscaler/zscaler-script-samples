variable "name_prefix" {
  description = "A prefix to associate to all the Cloud Connector module resources"
  default     = "zscaler-cc"
}

variable "resource_tag" {
  description = "A tag to associate to all the Cloud Connector module resources"
  default     = "cloud-connector"
}

variable "vpc" {
  description = "Cloud Connector VPC"
}

variable "cc_service_ips" {
  description = "Cloud Connector EC2 Instance service IPs"
}

variable "http_probe_port" {
  description = "port for Cloud Connector cloud init to enable listener port for HTTP probe from LB"
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
  type = bool
  default = false
}

variable "cc_subnet_ids" {
  description = "Cloud Connector subnet IDs list"
}

variable "global_tags" {
  description = "populate custom user provided tags"
}

variable "interval" {
  description = "default interval for gwlb target group health check probing"
  default     = 10
}

variable "healthy_threshold" {
  description = "default threshold for gwlb target group health check probing to report a target as healthy"
  default     = 3
}

variable "unhealthy_threshold" {
  description = "default threshold for gwlb target group health check probing to report a target as unhealthy"
  default     = 3
}


