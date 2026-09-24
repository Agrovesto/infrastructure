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
    databases = local.mssql_all_databases
    image     = var.mssql_image
    pid       = var.mssql_pid
    host_port = var.mssql_host_port
    subdomain = var.mssql_subdomain
  }

  # Password parameters the host reads at boot (dev/host_config.tf). Spelled as
  # deterministic ARNs so the instance policy does not depend on unknown resource
  # attributes or indexed counts at plan time.
  host_password_param_arns = [
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/mssql_sa_password",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/grafana_admin_password",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/sonarqube_db_password",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/redis_password",
  ]

  # ---------------------------------------------------------------------------
  # SonarQube
  #
  # The server is a container (docker-compose.yml.tftpl) on this host and its
  # database is the SQL Server container that is already here, so this section is
  # connection strings and one nginx vhost — no AWS resource beyond the volume in
  # dev/sonarqube.tf and the password parameter in dev/host_config.tf.
  # ---------------------------------------------------------------------------

  # The databases that actually get created and backed up: the caller's list plus
  # SonarQube's, unioned here rather than requiring it to be listed in two places.
  # Listing it twice is harmless — the union is deduplicated — but forgetting to
  # add it to mssql_databases would otherwise mean a database that is created and
  # never backed up, or the reverse.
  mssql_all_databases = distinct(concat(
    var.mssql_databases,
    var.sonarqube.enabled ? [var.sonarqube.database_name] : [],
  ))

  # 1433 is the container port, not var.mssql_host_port: that one is the host
  # publish (127.0.0.1:<host_port> -> 1433). SonarQube talks to SQL Server over
  # the compose network, where SQL Server always listens on 1433.
  #
  # trustServerCertificate is on because the SQL Server container presents a
  # self-signed certificate; without it the JDBC driver refuses the connection.
  # Encryption stays on — it is loopback-adjacent, but there is no reason to send
  # credentials in the clear.
  sonar_jdbc_url = join(";", concat(
    [
      "jdbc:sqlserver://mssql:1433",
      "databaseName=${var.sonarqube.database_name}",
      "encrypt=${var.sonarqube.jdbc_encrypt}",
    ],
    var.sonarqube.jdbc_trust_server_cert ? ["trustServerCertificate=true"] : [],
  ))

  # The vhost + allow list nginx renders for SonarQube, same shape as
  # local.logging_grafana: an empty allowed_cidrs is deliberately not "everyone",
  # it becomes 127.0.0.1, i.e. SSH-tunnel-only.
  sonarqube_nginx = {
    enabled   = var.sonarqube.enabled && var.sonarqube.expose_via_nginx
    subdomain = var.sonarqube.subdomain
    port      = 9000
    cidrs     = length(var.sonarqube.allowed_cidrs) > 0 ? var.sonarqube.allowed_cidrs : ["127.0.0.1"]
  }

  sonar_fqdn = "${var.sonarqube.subdomain}.${var.domain_name}"

  # SONAR_WEB_BASEURL. Has to be the URL a browser actually arrives on, not the
  # container's own address: SonarQube builds absolute links from it and compares
  # OAuth redirect origins against it. When nginx is not serving the vhost there
  # is no public name, so the loopback publish is the only honest answer.
  sonar_web_baseurl = var.sonarqube.expose_via_nginx ? "${var.sonarqube.scheme}://${local.sonar_fqdn}" : "http://127.0.0.1:${var.sonarqube.host_port}"

  nginx_upstreams = [
    for k, api in var.apis : {
      name      = k
      subdomain = api.subdomain
      port      = api.host_port
    }
  ]

  # ---------------------------------------------------------------------------
  # Logging & metrics on the host (Loki + Alloy + Grafana + Prometheus)
  #
  # Every file below is rendered at plan time and written by cloud-init, which is
  # how the compose and nginx configs already work. That has one consequence worth
  # knowing: user_data is immutable, so a config change replaces the instance.
  # dev/README.md has the day-2 loop that avoids that.
  #
  # Nothing in this section is an AWS resource except the small EBS volume the
  # stores sit on (see dev/logging.tf): the shipping, storage, querying and
  # visualising all happen inside the box.
  # ---------------------------------------------------------------------------

  logging_root = "/opt/agrovesto/logging"

  # The collector's own containers are dropped from its own inputs — Loki tailing
  # the logs of the thing that writes its logs is an unbounded loop that ends with
  # a full disk. See the drop rule in alloy-config.alloy.tftpl.
  logging_own_services = ["loki", "alloy", "grafana", "prometheus", "cadvisor", "node-exporter", "alertmanager"]

  # nginx is always parsed as JSON (its access log format is), plus whatever the
  # caller lists. Rendered as a LogQL/Prometheus regex alternation.
  logging_json_services = join("|", distinct(concat(["nginx"], var.logging.json_log_services)))

  # Loki's per-stream retention only earns its keep when it differs from the
  # global one; otherwise the config stays one line shorter.
  logging_retention_hours        = var.logging.loki_retention_days * 24
  logging_system_retention_hours = var.logging.system_retention_days * 24

  logging_retention_streams = var.logging.system_retention_days < var.logging.loki_retention_days ? [
    { selector = "{job=\"journal\"}", period = local.logging_system_retention_hours },
    { selector = "{component=\"nginx\"}", period = local.logging_system_retention_hours },
  ] : []

  # The vhost + allow list nginx renders for Grafana. An empty allowed_cidrs is
  # deliberately not "everyone": it becomes 127.0.0.1, i.e. SSH-tunnel-only.
  # `port` is the container port on the compose network, not the published host
  # port: nginx talks to grafana:3000, and nothing outside the box can.
  logging_grafana = {
    enabled   = var.logging.enabled && var.logging.expose_via_nginx
    subdomain = var.logging.grafana_subdomain
    port      = 3000
    cidrs     = length(var.logging.allowed_cidrs) > 0 ? var.logging.allowed_cidrs : ["127.0.0.1"]
  }

  grafana_fqdn = "${var.logging.grafana_subdomain}.${var.domain_name}"

  loki_config = templatefile("${path.module}/loki-config.yml.tftpl", {
    retention_hours        = local.logging_retention_hours
    ingestion_rate_mb      = var.logging.loki_ingestion_rate_mb
    ingestion_burst_mb     = var.logging.loki_ingestion_rate_mb * 2
    stream_rate_mb         = var.logging.loki_stream_rate_mb
    stream_burst_mb        = var.logging.loki_stream_rate_mb * 2
    max_entries            = var.logging.loki_max_entries
    max_query_length_hours = local.logging_retention_hours
    querier_max_concurrent = var.logging.querier_max_concurrent
    retention_streams      = local.logging_retention_streams
  })

  alloy_config = templatefile("${path.module}/alloy-config.alloy.tftpl", {
    metrics_port           = var.logging.alloy_port
    push_port              = var.logging.alloy_push_port
    hostname               = local.name
    journal_max_age        = var.logging.journal_max_age
    loki_url               = "http://loki:3100"
    json_log_services      = local.logging_json_services
    observability_services = local.logging_own_services
  })

  prometheus_config = templatefile("${path.module}/prometheus.yml.tftpl", {
    scrape_interval    = var.logging.scrape_interval_seconds
    project            = var.project
    environment        = var.environment
    hostname           = local.name
    node_exporter_port = var.logging.node_exporter_port
    cadvisor_port      = var.logging.cadvisor_port
    grafana_port       = var.logging.grafana_port
    metrics_port       = var.logging.alloy_port
    alertmanager_port  = var.logging.alertmanager_port
  })

  # Alert rules evaluated by the host's Prometheus; Alertmanager routes them to
  # the dev SNS alerts topic (sns.tf), the same place the CloudWatch alarms go.
  prometheus_rules = templatefile("${path.module}/prometheus-rules.yml.tftpl", {
    cpu_percent       = var.alert_rules.cpu_percent
    memory_percent    = var.alert_rules.memory_percent
    disk_free_percent = var.alert_rules.disk_free_percent
    # The containers that should always be up. Redis and SonarQube join the list
    # only when they exist, otherwise ContainerDown fires for a service that was
    # deliberately turned off.
    expected_containers = concat(
      keys(var.apis),
      ["nginx", "mssql", "vault"],
      var.redis.enabled ? ["redis"] : [],
      var.sonarqube.enabled ? ["sonarqube"] : [],
    )
  })

  # SNS receiver: signs with the instance role (IMDSv2, hop limit 2 in ec2.tf),
  # so no keys are configured.
  alertmanager_config = templatefile("${path.module}/alertmanager.yml.tftpl", {
    topic_arn = aws_sns_topic.alerts.arn
    region    = var.aws_region
    stack     = local.name
  })

  # Provisioning is file-based (the compose mounts are read-only bind mounts on
  # the logging volume), so the dashboards and datasources in this repository are
  # the only truth — nothing is clickable into existence.
  grafana_datasources = templatefile("${path.module}/grafana-datasources.yml.tftpl", {
    scrape_interval = var.logging.scrape_interval_seconds
  })

  grafana_dashboards_provider = file("${path.module}/grafana-dashboards.yml")
  grafana_dashboard_logs      = file("${path.module}/grafana/dashboards/dev-logs.json")
  grafana_dashboard_host      = file("${path.module}/grafana/dashboards/dev-host.json")

  # Host config in S3 ------------------------------------------------------------
  #
  # Every rendered file the box needs, one object each, keyed by the path it must
  # land on. user_data syncs the bucket instead of inlining them, because EC2 caps
  # instance user data at 16 KB and the compose project busts that on its own once
  # the logging stack is in it — and nothing new ends up in instance metadata.
  #
  # Keys are relative to /opt/agrovesto, so `docker compose up -d` still finds
  # ./docker-compose.yml and nginx's bind mount still finds ./nginx.conf.
  host_config_bucket = "${local.name}-host-config"

  host_config_files = merge(
    {
      "compose/docker-compose.yml" = {
        content      = local.docker_compose
        content_type = "text/yaml"
      }
      "nginx/nginx.conf" = {
        content      = local.nginx_conf
        content_type = "text/plain"
      }
      "scripts/init-dbs.sql" = {
        content      = local.init_sql
        content_type = "text/plain"
      }
    },
    var.logging.enabled ? {
      "logging/loki/config.yml" = {
        content      = local.loki_config
        content_type = "text/yaml"
      }
      "logging/alloy/config.alloy" = {
        content      = local.alloy_config
        content_type = "text/plain"
      }
      "logging/prometheus/prometheus.yml" = {
        content      = local.prometheus_config
        content_type = "text/yaml"
      }
      "logging/prometheus/rules/host.yml" = {
        content      = local.prometheus_rules
        content_type = "text/yaml"
      }
      "logging/alertmanager/alertmanager.yml" = {
        content      = local.alertmanager_config
        content_type = "text/yaml"
      }
      "logging/grafana/provisioning/datasources/datasources.yml" = {
        content      = local.grafana_datasources
        content_type = "text/yaml"
      }
      "logging/grafana/provisioning/dashboards/dashboards.yml" = {
        content      = local.grafana_dashboards_provider
        content_type = "text/yaml"
      }
      "logging/grafana/dashboards/dev-logs.json" = {
        content      = local.grafana_dashboard_logs
        content_type = "application/json"
      }
      "logging/grafana/dashboards/dev-host.json" = {
        content      = local.grafana_dashboard_host
        content_type = "application/json"
      }
    } : {},
  )

  docker_compose = templatefile("${path.module}/docker-compose.yml.tftpl", {
    apis              = var.apis
    mssql             = local.mssql
    vault             = var.vault
    redis             = var.redis
    sonarqube         = var.sonarqube
    sonar_jdbc_url    = local.sonar_jdbc_url
    sonar_web_baseurl = local.sonar_web_baseurl
    backup_bucket     = aws_s3_bucket.backup.bucket
    logging           = var.logging
    logging_root      = local.logging_root
  })

  nginx_conf = templatefile("${path.module}/nginx.conf.tftpl", {
    domain    = var.domain_name
    upstreams = local.nginx_upstreams
    grafana   = local.logging_grafana
    sonar     = local.sonarqube_nginx
  })

  # The boot-time SQL script (scripts/init-dbs.sql in the config bucket).
  #
  # Every database is a plain idempotent CREATE except SonarQube's, which cannot
  # take the server's default collation. SonarSource requires the database to be
  # case- AND accent-sensitive (CS_AS) — SQL Server's default here is
  # case-insensitive — and requires READ_COMMITTED_SNAPSHOT, without which
  # analyses deadlock under load. Both have to be set at create time: neither can
  # be changed later without rebuilding the database.
  #
  # The login password arrives as a sqlcmd variable ($(sonar_db_password), passed
  # with -v by user_data) and never as a literal here, because this string
  # becomes an object in the config bucket and secrets do not belong in S3.
  init_sql = join("\n", concat(
    [
      for db in local.mssql_all_databases :
      (var.sonarqube.enabled && db == var.sonarqube.database_name) ? "" : "IF DB_ID(N'${db}') IS NULL CREATE DATABASE [${db}];"
    ],
    var.sonarqube.enabled ? [
      "-- SonarQube: CS_AS collation is mandatory; the SQL Server default is not.",
      "IF DB_ID(N'${var.sonarqube.database_name}') IS NULL CREATE DATABASE [${var.sonarqube.database_name}] COLLATE ${var.sonarqube.database_collation};",
      "GO",
      "-- Mandatory as well. Only touched while it is off, so re-running this",
      "-- script cannot roll back the connections of a live SonarQube.",
      "IF (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = N'${var.sonarqube.database_name}') = 0",
      "  ALTER DATABASE [${var.sonarqube.database_name}] SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;",
      "GO",
      "-- A login scoped to this one database instead of `sa`, which would be",
      "-- sysadmin over the server and owner of the five application databases.",
      "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'${var.sonarqube.database_username}')",
      "  CREATE LOGIN [${var.sonarqube.database_username}] WITH PASSWORD = N'$(sonar_db_password)', CHECK_POLICY = ON;",
      "GO",
      "USE [${var.sonarqube.database_name}];",
      "GO",
      "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'${var.sonarqube.database_username}')",
      "BEGIN",
      "  CREATE USER [${var.sonarqube.database_username}] FOR LOGIN [${var.sonarqube.database_username}];",
      "  ALTER ROLE db_owner ADD MEMBER [${var.sonarqube.database_username}];",
      "END",
      "GO",
    ] : [],
  ))

  ec2_public_ip = var.associate_elastic_ip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip

  # ---------------------------------------------------------------------------
  # DNS
  # ---------------------------------------------------------------------------

  api_fqdns = { for k, api in var.apis : k => "${api.subdomain}.${var.domain_name}" }

  vault_fqdn = "${var.vault.subdomain}.${var.domain_name}"
  mssql_fqdn = "${local.mssql.subdomain}.${var.domain_name}"

  # Empty when DNS is managed from the prod account (var.manage_dns = false).
  zone_id = var.manage_dns && var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : var.existing_zone_id

  # Only HTTP backends are publicly routed through nginx.
  a_records = merge(
    { for k, api in var.apis : api.subdomain => local.ec2_public_ip },
    {
      (var.mssql_subdomain) = local.ec2_public_ip
    },
    # SonarQube gets a record only when it is actually served by nginx; with
    # expose_via_nginx = false there is nothing listening on that name, and a
    # record pointing at it would just be a dead hostname.
    local.sonarqube_nginx.enabled ? {
      (var.sonarqube.subdomain) = local.ec2_public_ip
    } : {},
    var.extra_a_records
  )

  # Frontends are served by Amplify; point their subdomains at the default
  # Amplify branch domain with a CNAME.
  cname_records = merge(
    {
      for k, app in var.amplify_apps :
      app.subdomain => "${app.branch}.${aws_amplify_app.this[k].id}.amplifyapp.com"
    },
    var.extra_cname_records
  )
}
