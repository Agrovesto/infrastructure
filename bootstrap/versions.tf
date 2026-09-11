# =============================================================================
# Bootstrap (prod account) — RUN ONCE, MANUALLY, FROM AN ADMIN WORKSTATION.
#
# This module is NOT part of the dev/prod pipelines: it has no CI workflow and
# keeps LOCAL state (gitignored). It creates the things the prod pipeline needs
# before it can exist:
#
#   1. S3 bucket for the prod Terraform state (referenced by prod/versions.tf)
#   2. GitHub Actions OIDC provider + deploy IAM role (ARN -> AWS_ROLE_ARN_PROD)
#
# Run it with admin credentials in the PROD account (e.g. SSO admin profile):
#
#   cd bootstrap
#   terraform init
#   terraform plan
#   terraform apply
#
# then follow the printed next_steps output.
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Deliberately NO backend: the state bucket doesn't exist yet. The local
  # terraform.tfstate this produces is small and gitignored — keep it safe; it
  # is the record of the deploy role + bucket.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Stack       = "bootstrap"
    }
  }
}
