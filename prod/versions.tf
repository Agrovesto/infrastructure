# Trigger CI test run
terraform {
  required_version = ">= 1.7.0" /* 1.7+ for mock_provider in terraform test */

  required_providers {
    aws    = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # The state bucket for the prod account is created by the run-once
  # bootstrap module (../bootstrap, see its README). Its `next_steps` output
  # replaces PROD_ACCOUNT_ID below with your prod account id.
  backend "s3" {
    bucket = "nomaos-tfstate-221434544570-eu-west-1"
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
