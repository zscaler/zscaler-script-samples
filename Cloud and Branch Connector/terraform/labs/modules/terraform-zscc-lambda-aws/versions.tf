terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version  = "~> 5.26.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.2.0"
    }
  }
  required_version = ">= 0.13.7, < 2.0.0"
}
