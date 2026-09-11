# =============================================================================
# Locals
#
# Everything the old per-module `locals` / `var.x` wiring used to do now happens
# here, because the whole stack lives in one flat root module.
# =============================================================================

locals {

  # ---------------------------------------------------------------------------
  # Naming
  # ---------------------------------------------------------------------------

  name = "${var.project}-${var.environment}"

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
    },
    var.tags
  )

  azs = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))

  # ---------------------------------------------------------------------------
  # EC2 host
  # ---------------------------------------------------------------------------

  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id

  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  mssql = {
    sa_password = var.mssql_sa_password
    databases   = var.mssql_databases
    image       = var.mssql_image
    host_port   = var.mssql_host_port
    subdomain   = var.mssql_subdomain
  }

  # Every HTTP backend gets a nginx server block: the APIs + Vault.
  nginx_upstreams = concat(
    [
      for k, api in var.apis : {
        name      = k
        subdomain = api.subdomain
        port      = api.host_port
      }
    ],
    [
      {
        name      = "vault"
        subdomain = var.vault.subdomain
        port      = var.vault.host_port
      }
    ]
  )

  docker_compose = templatefile("${path.module}/docker-compose.yml.tftpl", {
    apis          = var.apis
    mssql         = local.mssql
    vault         = var.vault
    backup_bucket = aws_s3_bucket.backup.id
  })

  nginx_conf = templatefile("${path.module}/nginx.conf.tftpl", {
    domain    = var.domain_name
    upstreams = local.nginx_upstreams
  })

  init_sql = join("\n", [
    for db in var.mssql_databases :
    "IF DB_ID(N'${db}') IS NULL CREATE DATABASE [${db}];"
  ])

  ec2_public_ip = var.associate_elastic_ip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip

  # ---------------------------------------------------------------------------
  # DNS
  # ---------------------------------------------------------------------------

  api_fqdns = { for k, api in var.apis : k => "${api.subdomain}.${var.domain_name}" }

  vault_fqdn = "${var.vault.subdomain}.${var.domain_name}"
  mssql_fqdn = "${local.mssql.subdomain}.${var.domain_name}"

  # Empty when DNS is managed from the prod account (var.manage_dns = false).
  zone_id = var.manage_dns && var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : var.existing_zone_id

  # All backend + vault names point at the public EC2 (nginx).
  a_records = merge(
    { for k, fqdn in local.api_fqdns : split(".", fqdn)[0] => local.ec2_public_ip },
    {
      vault = local.ec2_public_ip
      mssql = local.ec2_public_ip
    },
    var.extra_a_records
  )

  # Frontends are served by Amplify; point their subdomains at the default
  # Amplify branch domain with a CNAME.
  cname_records = merge(
    {
      for k, app in var.amplify_apps :
      app.subdomain => "${app.branch}.${aws_amplify_app.this[k].default_domain}"
    },
    var.extra_cname_records
  )
}
