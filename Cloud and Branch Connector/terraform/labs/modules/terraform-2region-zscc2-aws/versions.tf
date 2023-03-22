terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [aws.region1, aws.region2]
    }
  }
  required_version = ">= 0.13"
}
