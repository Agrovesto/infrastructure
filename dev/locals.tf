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

  # SSO is opt-in by credentials: all credentials empty keeps the existing local
  # login; a complete set enables GitHub login. The lifecycle precondition on the
  # host rejects partial sets before anything is replaced. Comparisons are made
  # non-sensitive explicitly — only these booleans are exposed, never a secret.
  sonarqube_github_credentials_set = [
    var.sonarqube_github_client_id != "",
    nonsensitive(var.sonarqube_github_client_secret != ""),
    var.sonarqube_github_app_id != "",
    nonsensitive(var.sonarqube_github_private_key != ""),
  ]
  sonarqube_github_configuration_valid = alltrue(local.sonarqube_github_credentials_set) || !anytrue(local.sonarqube_github_credentials_set)
  sonarqube_github_sso_enabled         = alltrue(local.sonarqube_github_credentials_set) && var.sonarqube.enabled && var.sonarqube.expose_via_nginx

  grafana_github_credentials_set = [
    var.grafana_github_client_id != "",
    nonsensitive(var.grafana_github_client_secret != ""),
  ]
  grafana_github_configuration_valid = alltrue(local.grafana_github_credentials_set) || !anytrue(local.grafana_github_credentials_set)
  grafana_github_team_organizations_valid = alltrue([
    for binding in var.grafana_github_team_roles :
    contains([for org in var.grafana_github_organizations : lower(org)], lower(binding.organization))
  ])
  grafana_github_sso_enabled = alltrue(local.grafana_github_credentials_set) && var.logging.enabled && var.logging.expose_via_nginx
  # Grafana evaluates this JMESPath expression against GitHub's /user/teams
  # response at every login. An unlisted team yields no role and strict mode
  # rejects the login. Sorting by role here guarantees highest-role-wins even if
  # callers reorder the input list.
  grafana_github_team_roles_by_priority = flatten([
    for role in ["Admin", "Editor", "Viewer"] : [
      for binding in var.grafana_github_team_roles : binding if binding.role == role
    ]
  ])
  grafana_github_role_attribute_path = join(" || ", concat(
    [
      for binding in local.grafana_github_team_roles_by_priority :
      "contains(groups[*], '@${binding.organization}/${binding.team_slug}') && '${binding.role}'"
    ],
    ["''"],
  ))

  github_sso_proxy_enabled = local.sonarqube_github_sso_enabled || local.grafana_github_sso_enabled

  sonarqube_github_parameter_names = {
    client_id     = "/${local.name}/sonarqube_github_client_id"
    client_secret = "/${local.name}/sonarqube_github_client_secret"
    app_id        = "/${local.name}/sonarqube_github_app_id"
    private_key   = "/${local.name}/sonarqube_github_private_key"
  }

  grafana_github_parameter_names = {
    client_id     = "/${local.name}/grafana_github_client_id"
    client_secret = "/${local.name}/grafana_github_client_secret"
  }

  # Secret parameters the host reads at boot (dev/host_config.tf). Spelled as
  # deterministic ARNs so the instance policy does not depend on unknown resource
  # attributes or indexed counts at plan time.
  host_password_param_arns = [
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/mssql_sa_password",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/grafana_admin_password",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/sonarqube_db_password",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/redis_password",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/sonarqube_github_client_id",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/sonarqube_github_client_secret",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/sonarqube_github_app_id",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/sonarqube_github_private_key",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/grafana_github_client_id",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/grafana_github_client_secret",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/vault_github_client_id",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/vault_github_client_secret",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/vault_oidc_client_secret",
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
  sonarqube_on_mssql    = var.sonarqube.enabled && var.sonarqube.database_engine == "mssql"
  sonarqube_on_postgres = var.sonarqube.enabled && var.sonarqube.database_engine == "postgres"

  mssql_all_databases = distinct(concat(
    var.mssql_databases,
    local.sonarqube_on_mssql ? [var.sonarqube.database_name] : [],
  ))

  # 1433 is the container port, not var.mssql_host_port: that one is the host
  # publish (127.0.0.1:<host_port> -> 1433). SonarQube talks to SQL Server over
  # the compose network, where SQL Server always listens on 1433.
  #
  # trustServerCertificate is on because the SQL Server container presents a
  # self-signed certificate; without it the JDBC driver refuses the connection.
  # Encryption stays on — it is loopback-adjacent, but there is no reason to send
  # credentials in the clear.
  sonar_jdbc_url = local.sonarqube_on_postgres ? "jdbc:postgresql://sonarqube-db:5432/${var.sonarqube.database_name}" : join(";", concat(
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

  # GitHub refuses an HTTP SonarQube callback. When credentials are present, the
  # Caddy edge container obtains and renews a public certificate and this becomes
  # the canonical URL regardless of the legacy `sonarqube.scheme` value.
  # Once Caddy is running (any SSO enabled) it serves HTTPS for every exposed UI,
  # not only the SSO ones, so the public scheme follows the proxy.
  sonar_public_scheme = local.github_sso_proxy_enabled && var.sonarqube.enabled && var.sonarqube.expose_via_nginx ? "https" : var.sonarqube.scheme

  # SONAR_WEB_BASEURL. Has to be the URL a browser actually arrives on, not the
  # container's own address: SonarQube builds absolute links from it and compares
  # OAuth redirect origins against it. When nginx is not serving the vhost there
  # is no public name, so the loopback publish is the only honest answer.
  sonar_web_baseurl = var.sonarqube.expose_via_nginx ? "${local.sonar_public_scheme}://${local.sonar_fqdn}" : "http://127.0.0.1:${var.sonarqube.host_port}"

  sonarqube_runtime = merge(var.sonarqube, {
    on_postgres               = local.sonarqube_on_postgres
    github_sso_enabled        = local.sonarqube_github_sso_enabled
    github_organizations      = join(",", var.sonarqube_github_organizations)
    github_allow_sign_up      = var.sonarqube_github_allow_sign_up
    github_synchronize_groups = var.sonarqube_github_synchronize_groups
  })

  nginx_upstreams = [
    for k, api in var.apis : {
      name      = k
      subdomain = api.subdomain
      port      = api.host_port
    }
  ]

  # File-storage Vault remains internal; only the opt-in OIDC deployment
  # allows requests from Caddy's public HTTPS edge to reach this vhost.
  vault_nginx = {
    subdomain    = var.vault.subdomain
    oidc_enabled = var.vault.oidc_enabled
  }
  vault_fqdn_for_oidc = "${var.vault.subdomain}.${var.domain_name}"
  vault_oidc_credentials_set = [
    var.vault_github_client_id != "",
    nonsensitive(var.vault_github_client_secret != ""),
    nonsensitive(var.vault_oidc_client_secret != ""),
  ]
  vault_oidc_credentials_valid = alltrue(local.vault_oidc_credentials_set)

  # API vhosts that opted into HTTPS with apis.<name>.tls_via_caddy (the agx
  # API). Each one gets a public certificate on the Caddy edge and a 308 from
  # plain HTTP; nginx keeps routing the vhost underneath.
  api_tls_domains = [
    for name, api in var.apis : "${api.subdomain}.${var.domain_name}" if api.tls_via_caddy
  ]

  # The TLS edge runs whenever something needs public HTTPS: GitHub SSO for the
  # dev UIs, Vault OIDC (whose Dex login broker serves at the Vault host's
  # /dex path), or an opted-in API vhost.
  tls_proxy_enabled = local.github_sso_proxy_enabled || var.vault.oidc_enabled || length(local.api_tls_domains) > 0

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
  logging_own_services = concat(
    ["loki", "alloy", "grafana", "prometheus", "cadvisor", "node-exporter", "alertmanager"],
    local.tls_proxy_enabled ? ["edge"] : [],
    var.vault.oidc_enabled ? ["dex"] : [],
  )

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

  grafana_fqdn          = "${var.logging.grafana_subdomain}.${var.domain_name}"
  grafana_public_scheme = local.github_sso_proxy_enabled && var.logging.enabled && var.logging.expose_via_nginx ? "https" : "http"

  logging_runtime = merge(var.logging, {
    grafana_root_url             = "${local.grafana_public_scheme}://${local.grafana_fqdn}"
    github_sso_enabled           = local.grafana_github_sso_enabled
    github_allowed_organizations = join(" ", var.grafana_github_organizations)
    github_allow_sign_up         = var.grafana_github_allow_sign_up
    github_role_attribute_path   = local.grafana_github_role_attribute_path
  })

  # Caddy is a narrow TLS edge in front of the existing nginx router. It serves
  # the SSO-enabled UI hosts, the Vault OIDC host (Dex for Vault's GitHub login)
  # and API vhosts that opted in with apis.<name>.tls_via_caddy; all source-IP
  # checks remain in nginx, which restores the client address from Caddy's
  # X-Forwarded-For header. Certificate state lives on one of the persistent
  # service volumes, so an EC2 replacement does not repeatedly consume ACME
  # issuance limits.
  github_sso_proxy = {
    enabled         = local.tls_proxy_enabled
    image           = "caddy:2.11.4-alpine"
    acme_email      = "tech@agrovesto.com"
    cpu_limit       = "0.10"
    memory_limit_mb = 128
    # Certificate state must outlive the root volume, so it goes on the
    # SonarQube or logging EBS volume whenever one of those stacks exists. A
    # host with neither has no persistent volume of its own and falls back to
    # /data/vault/caddy on the root disk. The SSO cases keep their historical
    # paths so an existing ACME account/certificates are not orphaned.
    data_dir = local.sonarqube_github_sso_enabled ? "${var.sonarqube.data_dir}/caddy" : local.grafana_github_sso_enabled ? "${local.logging_root}/caddy" : var.logging.enabled ? "${local.logging_root}/caddy" : "/data/vault/caddy"
    # The Vault host joins the edge only for Vault OIDC, where Dex serves at
    # its /dex path (the canonical issuer URL); the Vault UI itself stays
    # behind nginx's source-IP allow list until that same feature opens it.
    # The other UI hosts join once their GitHub SSO is configured, and API
    # vhosts when they set apis.<name>.tls_via_caddy.
    domains = compact(concat(
      [
        var.sonarqube.enabled && var.sonarqube.expose_via_nginx && local.github_sso_proxy_enabled ? local.sonar_fqdn : "",
        var.logging.enabled && var.logging.expose_via_nginx && local.github_sso_proxy_enabled ? local.grafana_fqdn : "",
        var.vault.oidc_enabled ? local.vault_fqdn_for_oidc : "",
      ],
      local.api_tls_domains,
    ))
  }

  caddyfile = local.tls_proxy_enabled ? templatefile("${path.module}/Caddyfile.tftpl", {
    email              = local.github_sso_proxy.acme_email
    domains            = local.github_sso_proxy.domains
    vault_oidc_enabled = var.vault.oidc_enabled
    vault_domain       = local.vault_fqdn_for_oidc
  }) : ""

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
      local.tls_proxy_enabled ? ["edge"] : [],
      var.vault.oidc_enabled ? ["dex"] : [],
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
    local.sonarqube_github_sso_enabled ? {
      "scripts/configure-sonarqube-team-permissions.sh" = {
        content      = file("${path.module}/configure-sonarqube-team-permissions.sh")
        content_type = "text/x-shellscript"
      }
    } : {},
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
    var.vault.oidc_enabled ? {
      "vault/operator.hcl" = {
        content      = file("${path.module}/vault-operator.hcl")
        content_type = "text/plain"
      }
      "scripts/configure-vault-oidc.sh" = {
        content = templatefile("${path.module}/configure-vault-oidc.sh", {
          vault_fqdn  = local.vault_fqdn_for_oidc
          github_org  = var.vault_github_organization
          github_team = var.vault_github_team_slug
        })
        content_type = "text/x-shellscript"
      }
      "scripts/refresh-vault-oidc.sh" = {
        content = templatefile("${path.module}/refresh-vault-oidc.sh.tftpl", {
          github_client_id_parameter     = aws_ssm_parameter.vault_github_client_id[0].name
          github_client_secret_parameter = aws_ssm_parameter.vault_github_client_secret[0].name
          oidc_secret_parameter          = aws_ssm_parameter.vault_oidc_client_secret[0].name
          aws_region                     = var.aws_region
          caddy_dir                      = local.github_sso_proxy.data_dir
        })
        content_type = "text/x-shellscript"
      }
      "vault/dex.yml" = {
        content = templatefile("${path.module}/dex.yml.tftpl", {
          fqdn = local.vault_fqdn_for_oidc
          org  = var.vault_github_organization
          team = var.vault_github_team_slug
        })
        content_type = "text/yaml"
      }
    } : {},
    local.tls_proxy_enabled ? {
      "edge/Caddyfile" = {
        content      = local.caddyfile
        content_type = "text/plain"
      }
    } : {},
  )

  docker_compose = templatefile("${path.module}/docker-compose.yml.tftpl", {
    apis              = var.apis
    mssql             = local.mssql
    vault             = var.vault
    domain            = var.domain_name
    redis             = var.redis
    sonarqube         = local.sonarqube_runtime
    sonar_jdbc_url    = local.sonar_jdbc_url
    sonar_web_baseurl = local.sonar_web_baseurl
    backup_bucket     = aws_s3_bucket.backup.bucket
    logging           = local.logging_runtime
    logging_root      = local.logging_root
    sso_proxy         = local.github_sso_proxy
  })

  nginx_conf = templatefile("${path.module}/nginx.conf.tftpl", {
    domain    = var.domain_name
    upstreams = local.nginx_upstreams
    grafana   = local.logging_grafana
    sonar     = local.sonarqube_nginx
    vault     = local.vault_nginx
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
      (local.sonarqube_on_mssql && db == var.sonarqube.database_name) ? "" : "IF DB_ID(N'${db}') IS NULL CREATE DATABASE [${db}];"
    ],
    local.sonarqube_on_mssql ? [
      "-- SonarQube: CS_AS collation is mandatory; the SQL Server default is not.",
      "IF DB_ID(N'${var.sonarqube.database_name}') IS NULL CREATE DATABASE [${var.sonarqube.database_name}] COLLATE ${var.sonarqube.database_collation};",
      "GO",
      "-- Mandatory as well. Only touched while it is off, so re-running this",
      "-- script cannot roll back the connections of a live SonarQube.",
      "IF (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = N'${var.sonarqube.database_name}') = 0",
      "  ALTER DATABASE [${var.sonarqube.database_name}] SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;",
      "GO",
      "-- A login scoped to this one database instead of `sa`, which would be",
      "-- sysadmin over the server and owner of the six managed application databases.",
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
      if app.publish_dns
    },
    var.extra_cname_records
  )
}
