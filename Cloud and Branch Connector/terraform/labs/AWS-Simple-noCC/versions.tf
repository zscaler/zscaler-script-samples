terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version  = "~> 4.2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    local = {
      source = "hashicorp/local"
    }
    # zpa = {
    #   source  = "zscaler/zpa"
    #   version = "2.1.2"
    # }
    null = {
      source = "hashicorp/null"
    }
  }
  required_version = ">= 0.13"
}