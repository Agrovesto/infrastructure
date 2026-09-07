locals {
  environment = "prod"
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
  single_nat_gateway       = false
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
  source             = "../../modules/edge"
  name               = local.name
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  certificate_arn    = module.dns.certificate_arn
  access_log_bucket  = module.foundation.access_log_bucket
  kms_key_arn        = module.foundation.kms_key_arn
  alerts_topic_arn   = module.foundation.alerts_topic_arn
  log_retention_days = var.log_retention_days
  enable_waf         = true
}
module "sql_secrets" {
  source      = "../../modules/sql_secrets"
  project     = var.project
  environment = local.environment
  databases   = var.databases
  kms_key_arn = module.foundation.kms_key_arn
}
module "native_backups" {
  source            = "../../modules/storage"
  name              = "${local.name}-${var.account_id}-${var.aws_region}-sql-backups"
  kms_key_arn       = module.foundation.kms_key_arn
  access_log_bucket = module.foundation.access_log_bucket
  expiration_days   = 90
  noncurrent_days   = 90
  object_lock_days  = 7
}
module "database" {
  source                    = "../../modules/rds_sqlserver"
  identifier                = var.rds_identifier
  name                      = local.name
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.database_subnet_ids
  client_security_group_ids = merge({ for k, s in var.services : k => module.services.security_group_ids[k] if s.database_key != null }, { sql_admin = module.services.admin_security_group_id })
  kms_key_arn               = module.foundation.kms_key_arn
  permissions_boundary_arn  = var.permissions_boundary_arn
  backup_bucket_arn         = module.native_backups.arn
  alerts_topic_arn          = module.foundation.alerts_topic_arn
  log_retention_days        = var.log_retention_days
  instance_class            = var.rds_instance_class
  engine_version            = var.rds_engine_version
  allocated_storage         = var.rds_allocated_storage
  max_allocated_storage     = var.rds_max_allocated_storage
  final_snapshot_identifier = var.rds_final_snapshot_identifier
}
module "services" {
  source                     = "../../modules/ecs"
  name                       = local.name
  region                     = var.aws_region
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.app_subnet_ids
  kms_key_arn                = module.foundation.kms_key_arn
  permissions_boundary_arn   = var.permissions_boundary_arn
  log_retention_days         = var.log_retention_days
  alerts_topic_arn           = module.foundation.alerts_topic_arn
  alb_security_group_id      = module.edge.security_group_id
  https_listener_arn         = module.edge.https_listener_arn
  alb_dns_name               = module.edge.dns_name
  alb_zone_id                = module.edge.zone_id
  alb_arn_suffix             = module.edge.arn_suffix
  zone_id                    = module.dns.zone_id
  zone_name                  = var.zone_name
  ecr_repository_arns        = local.pull_repository_arns
  database_host              = module.database.address
  database_security_group_id = module.database.security_group_id
  database_master_secret_arn = module.database.master_secret_arn
  databases                  = var.databases
  database_secret_arns       = module.sql_secrets.secret_arns
  sql_admin_image            = var.sql_admin_image == null ? "${local.registry}/${var.project}/sql-admin:bootstrap" : var.sql_admin_image
  services_enabled           = var.services_enabled
  services                   = var.services
}
