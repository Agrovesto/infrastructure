locals {
  environment = "dev"
  name        = "${var.project}-${local.environment}"
  registry    = "${var.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  pull_repository_arns = toset(flatten([for account in [var.account_id, var.peer_account_id] : [
    for repo in var.ecr_repositories : "arn:aws:ecr:${var.aws_region}:${account}:repository/${var.project}/${repo}"
  ]]))
}
provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = { Project = var.project, Environment = local.environment, ManagedBy = "Terraform" }
  }
}
module "foundation" {
  source                   = "../../modules/foundation"
  name                     = local.name
  project                  = var.project
  environment              = local.environment
  account_id               = var.account_id
  region                   = var.aws_region
  permissions_boundary_arn = var.permissions_boundary_arn
  alert_emails             = var.alert_emails
  monthly_budget_usd       = var.monthly_budget_usd
  log_retention_days       = var.log_retention_days
  enable_guardduty         = var.enable_guardduty
}
module "network" {
  source                   = "../../modules/network"
  name                     = local.name
  region                   = var.aws_region
  cidr                     = var.vpc_cidr
  availability_zones       = var.availability_zones
  single_nat_gateway       = true
  kms_key_arn              = module.foundation.kms_key_arn
  log_retention_days       = var.log_retention_days
  permissions_boundary_arn = var.permissions_boundary_arn
}
module "ecr" {
  source          = "../../modules/ecr"
  project         = var.project
  repositories    = var.ecr_repositories
  peer_account_id = var.peer_account_id
  kms_key_arn     = module.foundation.kms_key_arn
}
module "dns" {
  source           = "../../modules/dns"
  zone_name        = var.zone_name
  existing_zone_id = var.existing_zone_id
  records          = var.dns_records
  aliases          = var.dns_aliases
}
module "edge" {
  source            = "../../modules/edge"
  name              = local.name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  certificate_arn   = module.dns.certificate_arn
  access_log_bucket = module.foundation.access_log_bucket
  alerts_topic_arn  = module.foundation.alerts_topic_arn
}
module "sql_secrets" {
  source      = "../../modules/sql_secrets"
  project     = var.project
  environment = local.environment
  databases   = var.databases
  kms_key_arn = module.foundation.kms_key_arn
}
module "frontends" {
  source    = "../../modules/amplify"
  zone_id   = module.dns.zone_id
  name      = local.name
  zone_name = var.zone_name
  frontends = var.frontends
}
module "host" {
  source                   = "../../modules/dev_host"
  name                     = local.name
  project                  = var.project
  region                   = var.aws_region
  account_id               = var.account_id
  vpc_id                   = module.network.vpc_id
  subnet_id                = module.network.app_subnet_ids[0]
  availability_zone        = var.availability_zones[0]
  kms_key_arn              = module.foundation.kms_key_arn
  permissions_boundary_arn = var.permissions_boundary_arn
  access_log_bucket        = module.foundation.access_log_bucket
  alerts_topic_arn         = module.foundation.alerts_topic_arn
  log_retention_days       = var.log_retention_days
  alb_security_group_id    = module.edge.security_group_id
  https_listener_arn       = module.edge.https_listener_arn
  alb_dns_name             = module.edge.dns_name
  alb_zone_id              = module.edge.zone_id
  alb_arn_suffix           = module.edge.arn_suffix
  zone_id                  = module.dns.zone_id
  zone_name                = var.zone_name
  ecr_repository_arns      = local.pull_repository_arns
  databases                = var.databases
  database_secret_arns     = module.sql_secrets.secret_arns
  services_enabled         = var.services_enabled
  services                 = var.services
  instance_type            = var.instance_type
  ami_id                   = var.ami_id
  root_volume_size         = var.root_volume_size
  database_volume_size     = var.database_volume_size
  sqlserver_image          = var.sqlserver_image
  accept_sqlserver_eula    = var.accept_sqlserver_eula
}
