data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project}-dev"
  azs  = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))
  tags = {
    Project     = var.project
    Environment = "dev"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name                = local.name
  cidr_block          = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = local.azs
  tags                = local.tags
}

module "security_groups" {
  source = "../../modules/security_groups"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  tags              = local.tags
}

module "backup" {
  source = "../../modules/s3_backup"

  name            = "${local.name}-mssql-backups"
  force_destroy   = true
  expiration_days = var.backup_retention_days
  tags            = local.tags
}

module "iam" {
  source = "../../modules/iam"

  name              = local.name
  backup_bucket_arn = module.backup.bucket_arn
  tags              = local.tags
}

module "ec2" {
  source = "../../modules/ec2_stack"

  name                  = local.name
  subnet_id             = module.vpc.public_subnet_ids[0]
  security_group_ids    = [module.security_groups.ec2_security_group_id]
  instance_profile_name = module.iam.instance_profile_name
  instance_type         = var.instance_type
  key_name              = var.key_name
  root_volume_size_gb   = var.root_volume_size_gb
  mssql_volume_size_gb  = var.mssql_volume_size_gb
  domain_name           = var.domain_name
  apis                  = var.apis
  backup_bucket         = module.backup.bucket_id
  aws_region            = var.aws_region
  tags                  = local.tags

  mssql = {
    sa_password = var.mssql_sa_password
    databases   = var.mssql_databases
    image       = var.mssql_image
    host_port   = 1433
    subdomain   = "mssql"
  }
}

module "scheduler" {
  source = "../../modules/eventbridge_ec2_scheduler"

  name               = local.name
  instance_id        = module.ec2.instance_id
  scheduler_role_arn = module.iam.scheduler_role_arn
  timezone           = var.scheduler_timezone
  start_cron         = var.ec2_start_cron
  stop_cron          = var.ec2_stop_cron
  enabled            = var.enable_ec2_scheduler
  tags               = local.tags
}

module "amplify" {
  source = "../../modules/amplify"

  apps                 = var.amplify_apps
  github_access_token  = var.github_access_token
  domain_name          = var.domain_name
  # Route53 CNAMEs are used instead of Amplify domain association so multiple
  # apps can share one parent domain without colliding.
  enable_custom_domain = false
  tags                 = local.tags
}

module "dns" {
  source = "../../modules/route53"

  domain_name      = var.domain_name
  create_zone      = var.create_hosted_zone
  existing_zone_id = var.existing_zone_id
  tags             = local.tags

  # All backend + vault names point at the public EC2 (nginx)
  a_records = merge(
    { for k, fqdn in module.ec2.api_fqdns : split(".", fqdn)[0] => module.ec2.public_ip },
    {
      vault = module.ec2.public_ip
      mssql = module.ec2.public_ip
    }
  )

  cname_records = {
    for k, app in var.amplify_apps :
    app.subdomain => "${app.branch}.${module.amplify.default_domains[k]}"
  }
}
