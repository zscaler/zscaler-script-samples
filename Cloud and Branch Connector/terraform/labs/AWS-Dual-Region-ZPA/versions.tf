terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version  = "~> 4.2.0"
      configuration_aliases = [aws.region1, aws.region2]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    local = {
      source = "hashicorp/local"
    }
    null = {
      source = "hashicorp/null"
    }
    zpa = {
      source  = "zscaler/zpa"
      version = "3.0.0"
    }
  }
  required_version = ">= 0.13"
}