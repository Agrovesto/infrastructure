terraform {
  required_version = ">= 1.6.0"

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
