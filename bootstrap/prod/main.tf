provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = { Project = var.project, Environment = "prod", ManagedBy = "Terraform", Component = "bootstrap" }
  }
}
module "account" {
  source                     = "../../modules/account_bootstrap"
  project                    = var.project
  environment                = "prod"
  account_id                 = var.account_id
  region                     = var.aws_region
  github_repository          = var.github_repository
  existing_oidc_provider_arn = var.existing_oidc_provider_arn
  github_oidc_subject        = var.github_oidc_subject
  bootstrap_zone_name        = var.bootstrap_zone_name
}
