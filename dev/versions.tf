# Trigger CI test run - fix locals string concat and mock policy docs
terraform {
  required_version = ">= 1.7.0" /* 1.7+ for mock_provider in terraform test */

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40" # aws_rekognition_collection
    }
  }

  # Point this at a backend when ready:
  backend "s3" {
    bucket = "nomaos-tfstate-353833416626-eu-west-1"
    key    = "dev/bootstrap.tfstate"
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
