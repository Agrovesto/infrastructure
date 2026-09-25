# =============================================================================
# Locals
#
# Same flat-module conventions as the dev stack: naming, tags, AZ selection,
# rendered config and DNS maps all live here.
# =============================================================================

locals {

  # ---------------------------------------------------------------------------
  # Naming (same convention as dev: <project>-<environment>)
  # ---------------------------------------------------------------------------

  name = "${var.project}-${var.environment}"

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
    },
    var.tags
  )

  # Public/private/database subnet counts are independent lists; every list is
  # aligned with the first N AZs of the region.
  azs = slice(
    data.aws_availability_zones.available.names,
    0,
    max(
      length(var.public_subnet_cidrs),
      length(var.private_subnet_cidrs),
      length(var.database_subnet_cidrs),
    )
  )

  # NAT gateways: one per public subnet (HA, prod default) or a single shared one.
  nat_count = var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)

  # ---------------------------------------------------------------------------
  # OpenTelemetry
  # ---------------------------------------------------------------------------

  # OTEL_RESOURCE_ATTRIBUTES: comma-separated key=value pairs that label every
  # span, metric and log the SDK emits, so Grafana can group a trace by
  # environment or cluster without the app having to set them.
  #
  # The computed defaults go first and var.otel.resource_attributes is merged
  # over them, so a caller can override deployment.environment but cannot
  # accidentally produce a string with no identity in it. `for` over a map
  # iterates in lexical key order, which keeps the rendered string — and
  # therefore the task definition, and therefore the plan — stable.
  otel_resource_attributes = join(",", [
    for k, v in merge(
      {
        "deployment.environment" = var.environment
        "service.namespace"      = var.project
        "cloud.provider"         = "aws"
        "cloud.region"           = var.aws_region
        "aws.ecs.cluster.name"   = local.name
      },
      var.otel.resource_attributes,
    ) : "${k}=${v}"
  ])

  # The OTel environment block, identical for every service except
  # OTEL_SERVICE_NAME (which each task definition sets to its own key).
  otel_environment = var.otel.enabled ? [
    { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = var.otel.endpoint },
    { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = var.otel.protocol },
    { name = "OTEL_TRACES_EXPORTER", value = var.otel.traces_exporter },
    { name = "OTEL_METRICS_EXPORTER", value = var.otel.metrics_exporter },
    { name = "OTEL_LOGS_EXPORTER", value = var.otel.logs_exporter },
    { name = "OTEL_TRACES_SAMPLER", value = var.otel.traces_sampler },
    { name = "OTEL_TRACES_SAMPLER_ARG", value = var.otel.traces_sampler_arg },
    { name = "OTEL_PROPAGATORS", value = join(",", var.otel.propagators) },
    { name = "OTEL_RESOURCE_ATTRIBUTES", value = local.otel_resource_attributes },
  ] : []

  # ---------------------------------------------------------------------------
  # Services / DNS
  # ---------------------------------------------------------------------------

  # <subdomain>.<domain> for every service (+ Vault), e.g. wallet.nomaos.com
  service_fqdns = merge(
    { for k, svc in var.services : k => "${svc.subdomain}.${var.domain_name}" },
    var.enable_vault ? { vault = "${var.vault_subdomain}.${var.domain_name}" } : {}
  )

  # Every distinct task port the ALB must reach (service ports + Vault's).
  service_ports = toset(concat(
    [for svc in var.services : svc.port],
    var.enable_vault ? [var.vault_port] : []
  ))

  zone_id = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : var.existing_zone_id

  # Alias records point every service subdomain (and Vault's) at the public ALB.
  service_alias_records = merge(
    { for k, svc in var.services : svc.subdomain => {
      name                   = try(aws_lb.main.dns_name, "mock-alb.elb.amazonaws.com")
      zone_id                = try(aws_lb.main.zone_id, "Z2FDTNDATAQYW2")
      evaluate_target_health = true
    } },
    var.enable_vault ? { (var.vault_subdomain) = {
      name                   = try(aws_lb.main.dns_name, "mock-alb.elb.amazonaws.com")
      zone_id                = try(aws_lb.main.zone_id, "Z2FDTNDATAQYW2")
      evaluate_target_health = true
    } } : {}
  )

  alias_records = merge(local.service_alias_records, var.extra_alias_records)

  # ---------------------------------------------------------------------------
  # MSSQL
  # ---------------------------------------------------------------------------

  # Same SQL the dev stack runs in its bootstrap: create every database if the
  # instance doesn't have it yet. Consumed by the optional db-init task
  # (var.run_db_init) and printed in the outputs as a manual runbook.
  db_init_sql = join(" ", [
    for db in var.mssql_databases :
    "IF DB_ID(N'${db}') IS NULL CREATE DATABASE [${db}];"
  ])

  db_size_check_family = "${local.name}-db-size-check"

  # One line per user database: "DB_SIZE_OK <db> <mb>MB" or "DB_SIZE_ALERT <db>
  # <mb>MB". size is in 8 KB pages, so *8/1024 is MB. type = 0 is data files —
  # Express's 10 GB cap counts data, not the transaction log.
  db_size_check_sql = "SET NOCOUNT ON; SELECT CASE WHEN SUM(size)*8/1024 > ${var.db_size_alarm_threshold_mb} THEN 'DB_SIZE_ALERT ' + DB_NAME(database_id) + ' ' + CAST(SUM(size)*8/1024 AS varchar(20)) + 'MB' ELSE 'DB_SIZE_OK ' + DB_NAME(database_id) + ' ' + CAST(SUM(size)*8/1024 AS varchar(20)) + 'MB' END FROM sys.master_files WHERE database_id > 4 AND type = 0 GROUP BY database_id;"
}
