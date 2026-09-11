terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # TODO(prod-account): create the Terraform state bucket in the PROD account
  # (same convention as dev: nomaos-tfstate-<account-id>-<region>) and replace
  # PROD_ACCOUNT_ID below before running `terraform init`.
  backend "s3" {
    bucket = "nomaos-tfstate-PROD_ACCOUNT_ID-eu-west-1"
    key    = "prod/bootstrap.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
