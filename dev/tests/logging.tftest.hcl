# =============================================================================
# DEV — on-host logging, metrics & traces (Loki + Tempo + Alloy + Grafana + Prometheus)
#
# The stack is containers on the app host, so most of what there is to assert
# lives in the rendered files rather than in AWS resources: the compose project,
# the nginx vhost, the collector pipeline, and the config objects that cloud-init
# syncs down. That is what this suite pins.
#
# Run with:  terraform -chdir=dev init && terraform -chdir=dev test
# =============================================================================

mock_provider "aws" {}

override_data {
  target = data.aws_availability_zones.available
  values = {
    names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  }
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:root"
  }
}

override_data {
  target = data.aws_ami.ubuntu
  values = {
    id = "ami-0123456789abcdef0"
  }
}

override_data {
  target = data.aws_iam_policy_document.ec2_assume
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.ec2
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

variables {
  ui_https_enabled   = false
  vault              = { subdomain = "dev-vault", oidc_enabled = false }
  manage_fresh_vault = false
  import_existing    = false

  ami_id            = "ami-0123456789abcdef0"
  domain_name       = "nomaos.com"
  mssql_sa_password = "Str0ng!TestOnly" # ggignore - test fixture, not a credential
  mssql_databases   = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]

  apis = {
    nomaos = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5000
      subdomain = "noma-wallet-api"
      blue_green = {
        blue_port  = 5007
        green_port = 5008
      }
    }
    wallet = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5001
      subdomain = "dev-wallet-api"
      blue_green = {
        blue_port  = 5009
        green_port = 5010
      }
    }
    onboarding = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5002
      subdomain = "dev-onboarding-api"
    }
  }

  amplify_apps = {
    landing = {
      repository = "https://github.com/Agrovesto/nomaos-landingpage"
      branch     = "dev"
      subdomain  = "dev-agrovesto"
      framework  = "React"
    }
  }
}

# -----------------------------------------------------------------------------
# The stack exists, on its own disk, with its config in S3
# -----------------------------------------------------------------------------

run "logging_stack_resources" {
  command = plan

  assert {
    condition     = length(aws_ebs_volume.logging) == 1 && length(aws_volume_attachment.logging) == 1
    error_message = "Enabled logging gets its own EBS volume, attached to the app host."
  }

  assert {
    condition     = aws_ebs_volume.logging[0].encrypted && aws_ebs_volume.logging[0].type == "gp3"
    error_message = "The log volume is encrypted gp3, like the SQL Server data volume."
  }

  assert {
    condition     = aws_ebs_volume.logging[0].tags["Purpose"] == "loki-prometheus-grafana"
    error_message = "The volume is tagged so its cost is attributable to the logging stack."
  }

  assert {
    condition     = aws_volume_attachment.logging[0].device_name == var.logging.volume_device
    error_message = "The attachment uses the device the bootstrap script probes for."
  }

  assert {
    condition     = length(aws_s3_object.host_config) == 19
    error_message = "Nineteen rendered files ship to the host: the five always-needed (compose, nginx.conf, one blue/green slot file per opted-in API — nomaos and wallet here — and init-dbs.sql), then loki and its ruler rules, tempo, alloy, prometheus, its host rules, alertmanager, 2x grafana provisioning and 5x dashboards."
  }

  assert {
    condition = alltrue([
      for k, o in aws_s3_object.host_config :
      startswith(o.key, "compose/") || startswith(o.key, "nginx/") ||
      startswith(o.key, "scripts/") || startswith(o.key, "logging/")
    ])
    error_message = "Every key is a path under /opt/agrovesto, which is the tree the sync lays out."
  }

  # The bucket has to carry exactly what the host reads, so equality with the
  # rendered local is the assertion that matters - not a substring of it.
  assert {
    condition = (
      aws_s3_object.host_config["compose/docker-compose.yml"].content == local.docker_compose &&
      aws_s3_object.host_config["nginx/nginx.conf"].content == local.nginx_conf &&
      aws_s3_object.host_config["nginx/nomaos_api-active.conf"].content == local.blue_green_slot_confs["nginx/nomaos_api-active.conf"].content &&
      aws_s3_object.host_config["logging/loki/config.yml"].content == local.loki_config
    )
    error_message = "Objects must be the rendered files verbatim; user_data syncs them without editing."
  }
  assert {
    condition = (
      aws_s3_bucket_public_access_block.host_config.block_public_acls &&
      aws_s3_bucket_versioning.host_config.versioning_configuration[0].status == "Enabled" &&
      alltrue([for rule in aws_s3_bucket_server_side_encryption_configuration.host_config.rule :
        alltrue([for encryption in rule.apply_server_side_encryption_by_default : encryption.sse_algorithm == "AES256"])
      ]) &&
      alltrue([for rule in aws_s3_bucket_lifecycle_configuration.host_config.rule :
        alltrue([for expiration in rule.noncurrent_version_expiration : expiration.noncurrent_days == 30])
      ])
    )
    error_message = "The config bucket carries the same four hardening blocks as the backup bucket."
  }

}

# -----------------------------------------------------------------------------
# compose: the observability containers, loopback-only, inside everyone's limits
# -----------------------------------------------------------------------------

run "compose_services" {
  command = plan

  assert {
    condition = alltrue([
      for image in [
        var.logging.loki_image,
        var.logging.tempo_image,
        var.logging.alloy_image,
        var.logging.grafana_image,
        var.logging.prometheus_image,
        var.logging.cadvisor_image,
        var.logging.node_exporter_image,
      ] : strcontains(local.docker_compose, "image: ${image}")
    ])
    error_message = "Every pinned observability image must reach the compose file."
  }

  assert {
    condition     = strcontains(local.docker_compose, "container_name: agrovesto-node-exporter")
    error_message = "Container names keep the agrovesto- prefix: the collector derives the `service` label from it."
  }

  assert {
    condition = alltrue([
      for port in [var.logging.grafana_port, var.logging.loki_port, var.logging.tempo_port, var.logging.prometheus_port, var.logging.cadvisor_port, var.logging.node_exporter_port, var.logging.alloy_port, var.logging.alloy_otlp_grpc_port, var.logging.alloy_otlp_http_port, var.logging.alertmanager_port] :
      strcontains(local.docker_compose, "127.0.0.1:${port}:")
    ])
    error_message = "No component of this stack publishes a non-loopback port; the security group stays as it was."
  }

  assert {
    condition     = strcontains(local.docker_compose, "MSSQL_SA_PASSWORD") && strcontains(local.docker_compose, "$${GRAFANA_ADMIN_PASSWORD}")
    error_message = "Secrets stay in the compose .env file, referenced as $$VAR, never written into the compose file itself."
  }

  assert {
    # 8 observability containers, plus Redis and SonarQube when they are on: the
    # count has to follow what is enabled, or disabling either service turns this
    # into a false failure.
    condition     = length(regexall("mem_limit:", local.docker_compose)) == 8 + (var.redis.enabled ? 1 : 0) + (var.sonarqube.enabled ? 1 : 0) + (local.sonarqube_on_postgres ? 1 : 0)
    error_message = "Every capped container carries a memory limit — the eight observability ones, plus Redis and SonarQube when enabled — so none of them can starve SQL Server."
  }

  assert {
    condition     = strcontains(local.docker_compose, "prom/alertmanager") && strcontains(local.docker_compose, "/prometheus/rules:/etc/prometheus/rules:ro")
    error_message = "Alertmanager runs next to Prometheus, which gets its rules directory mounted."
  }

  assert {
    condition     = strcontains(local.prometheus_config, "rule_files:") && strcontains(local.prometheus_config, "alertmanager:9093")
    error_message = "Prometheus loads the alert rules and sends firing alerts to Alertmanager."
  }

  assert {
    # The rendered config holds the topic ARN (unknown in plan); check the template.
    condition     = aws_s3_object.host_config["logging/alertmanager/alertmanager.yml"].key == "logging/alertmanager/alertmanager.yml" && strcontains(file("alertmanager.yml.tftpl"), "sns_configs:") && strcontains(file("alertmanager.yml.tftpl"), "sigv4:")
    error_message = "Alertmanager publishes to the SNS alerts topic, signed with the instance role."
  }

  assert {
    condition     = strcontains(local.prometheus_rules, "up == 0") && strcontains(local.prometheus_rules, "container_last_seen") && strcontains(local.prometheus_rules, "> 90")
    error_message = "The host rules cover scrape targets, containers and the default thresholds."
  }

  assert {
    condition     = aws_instance.app.metadata_options[0].http_put_response_hop_limit == 2 && aws_instance.app.metadata_options[0].http_tokens == "required"
    error_message = "Containers reach the instance role over IMDSv2 only (hop limit 2)."
  }

  assert {
    condition     = aws_iam_role_policy.ec2_alerts_sns.name == "${local.name}-ec2-alerts-sns"
    error_message = "The EC2 role may publish to the alerts topic for Alertmanager."
  }

  assert {
    condition     = strcontains(local.docker_compose, "grafana/loki") && strcontains(local.docker_compose, "/loki:/loki")
    error_message = "Loki's config, chunks and WAL live on the logging volume, not on the root disk."
  }
}

# -----------------------------------------------------------------------------
# The collector pipeline
# -----------------------------------------------------------------------------

run "alloy_pipeline" {
  command = plan

  assert {
    condition = alltrue([
      strcontains(local.alloy_config, "loki.source.docker"),
      strcontains(local.alloy_config, "loki.source.journal"),
      strcontains(local.alloy_config, "loki.source.api"),
      strcontains(local.alloy_config, "loki.write"),
      strcontains(local.alloy_config, "otelcol.receiver.otlp"),
      strcontains(local.alloy_config, "otelcol.exporter.otlp \"tempo\""),
    ])
    error_message = "Three log inputs (containers, journald, push API), the OTLP receiver and their outputs (Loki, Tempo) must all be wired."
  }

  assert {
    condition     = strcontains(local.alloy_config, "unix:///var/run/docker.sock")
    error_message = "Container logs are read from the docker daemon, so no app service needs a logging driver of its own."
  }

  assert {
    condition     = strcontains(local.alloy_config, "\"${join("|", local.logging_own_services)}\"")
    error_message = "The collector drops the stack's own containers: Loki reading its own logs is an unbounded loop."
  }

  assert {
    condition     = strcontains(local.alloy_config, "/loki/api/v1/push")
    error_message = "Loki is written over its push API on the compose network, not through a published port."
  }
}

# -----------------------------------------------------------------------------
# Traces: OTLP in, Tempo on the volume, spans queryable in Grafana
# -----------------------------------------------------------------------------

run "traces_pipeline" {
  command = plan

  assert {
    condition = (
      strcontains(local.docker_compose, "container_name: agrovesto-tempo") &&
      strcontains(local.docker_compose, "image: ${var.logging.tempo_image}") &&
      aws_s3_object.host_config["logging/tempo/config.yml"].content == local.tempo_config
    )
    error_message = "Tempo runs as a capped container with its rendered config shipped through the host config bucket, like every other component."
  }

  assert {
    condition = (
      strcontains(local.tempo_config, "block_retention: ${var.logging.traces_retention_hours}h") &&
      strcontains(local.tempo_config, "endpoint: 0.0.0.0:4317") &&
      strcontains(local.tempo_config, "url: http://prometheus:9090/api/v1/write")
    )
    error_message = "Tempo keeps traces for traces_retention_hours, accepts OTLP on the standard ports and remote-writes span metrics to Prometheus."
  }

  assert {
    condition = (
      strcontains(local.grafana_datasources, "uid: agrovesto-tempo") &&
      strcontains(local.grafana_datasources, "datasourceUid: agrovesto-tempo") &&
      strcontains(local.grafana_datasources, "datasourceUid: agrovesto-loki") &&
      strcontains(local.grafana_datasources, "$${__value.raw}")
    )
    error_message = "Grafana gets a Tempo datasource, a Loki log-line -> trace link and the trace -> logs jump back."
  }

  assert {
    condition = (
      strcontains(local.prometheus_config, "job_name: tempo") &&
      strcontains(local.docker_compose, "--web.enable-remote-write-receiver")
    )
    error_message = "Prometheus scrapes Tempo's own metrics and has the remote-write receiver on for Tempo's span metrics."
  }

  assert {
    condition = (
      strcontains(local.docker_compose, "OTEL_EXPORTER_OTLP_ENDPOINT") &&
      strcontains(local.docker_compose, "OTEL_SERVICE_NAME: \"nomaos\"") &&
      strcontains(local.docker_compose, "127.0.0.1:${var.logging.alloy_otlp_grpc_port}:4317")
    )
    error_message = "Every compose API carries the OTEL env block (service name = API key) and Alloy's OTLP receiver is loopback-published."
  }

  assert {
    condition     = contains(local.logging_own_services, "tempo")
    error_message = "Tempo's own logs are dropped by the collector like the rest of the stack's containers."
  }
}

# -----------------------------------------------------------------------------
# Dashboards: what the metrics, logs and traces are looked at through
# -----------------------------------------------------------------------------

run "grafana_dashboards" {
  command = plan

  assert {
    condition = alltrue([
      for name, content in {
        "dev-logs"     = local.grafana_dashboard_logs
        "dev-host"     = local.grafana_dashboard_host
        "dev-services" = local.grafana_dashboard_services
        "dev-traffic"  = local.grafana_dashboard_traffic
        "dev-infra"    = local.grafana_dashboard_infra
      } :
      aws_s3_object.host_config["logging/grafana/dashboards/${name}.json"].content == content &&
      aws_s3_object.host_config["logging/grafana/dashboards/${name}.json"].content_type == "application/json"
    ])
    error_message = "Every dashboard in dev/grafana/dashboards ships to the host verbatim, as JSON, under the directory the file provider reads."
  }

  assert {
    condition = alltrue([
      strcontains(local.grafana_dashboard_services, "agrovesto-dev-services"),
      strcontains(local.grafana_dashboard_services, "container_cpu_usage_seconds_total"),
      strcontains(local.grafana_dashboard_services, "container_spec_memory_limit_bytes"),
      strcontains(local.grafana_dashboard_services, "container_spec_cpu_quota"),
      strcontains(local.grafana_dashboard_services, "container_oom_events_total"),
    ])
    error_message = "The services dashboard answers CPU and memory per app, measured against each container's own compose limit, plus restarts and OOM kills."
  }

  assert {
    condition = alltrue([
      strcontains(local.grafana_dashboard_traffic, "agrovesto-dev-traffic"),
      strcontains(local.grafana_dashboard_traffic, "count_over_time"),
      strcontains(local.grafana_dashboard_traffic, "[1d]"),
      strcontains(local.grafana_dashboard_traffic, "remote_addr"),
      strcontains(local.grafana_dashboard_traffic, "http_user_agent"),
      strcontains(local.grafana_dashboard_traffic, "quantile_over_time"),
    ])
    error_message = "The traffic dashboard counts requests per day per vhost and breaks them down by client IP, URI and user agent out of the nginx JSON access log."
  }

  assert {
    condition = alltrue([
      strcontains(local.grafana_dashboard_infra, "agrovesto-dev-infra"),
      strcontains(local.grafana_dashboard_infra, "node_filesystem_avail_bytes"),
      strcontains(local.grafana_dashboard_infra, "node_network_receive_bytes_total"),
      strcontains(local.grafana_dashboard_infra, "container_spec_memory_limit_bytes"),
      strcontains(local.grafana_dashboard_infra, "tempo_distributor_spans_received_total"),
      strcontains(local.grafana_dashboard_infra, "traces_span_metrics_calls_total"),
      strcontains(local.grafana_dashboard_infra, "ALERTS"),
    ])
    error_message = "The infrastructure dashboard covers the host, what the containers do to it, the observability stack watching both, and the alerts."
  }

  assert {
    condition     = strcontains(local.grafana_dashboards_provider, "path: /var/lib/grafana/dashboards")
    error_message = "The file provider still points at the directory the sync fills, so adding a dashboard is a file in this repository and nothing else."
  }
}

# -----------------------------------------------------------------------------
# Alerts: resource rules in Prometheus, log rules in Loki's own ruler
# -----------------------------------------------------------------------------

run "container_resource_alerts" {
  command = plan

  assert {
    condition = alltrue([
      strcontains(local.prometheus_rules, "HostHighCpu"),
      strcontains(local.prometheus_rules, "ContainerDown"),
      strcontains(local.prometheus_rules, "ContainerRestarting"),
      strcontains(local.prometheus_rules, "ContainerNearMemoryLimit"),
      strcontains(local.prometheus_rules, "ContainerHighCpu"),
      strcontains(local.prometheus_rules, "ContainerCpuThrottled"),
    ])
    error_message = "The host rules must cover the box and the containers on it: down, restarting, memory near the limit, CPU near the limit, and CPU throttling."
  }

  assert {
    condition = alltrue([
      strcontains(local.prometheus_rules, "> ${var.alert_rules.container_memory_percent}"),
      strcontains(local.prometheus_rules, "> ${var.alert_rules.container_cpu_percent}"),
      strcontains(local.prometheus_rules, "> ${var.alert_rules.container_throttled_percent}"),
    ])
    error_message = "Container thresholds come from var.alert_rules, not from the template, so they can be raised without editing it."
  }

  assert {
    condition     = aws_s3_object.host_config["logging/prometheus/rules/host.yml"].content == local.prometheus_rules
    error_message = "The rendered rules ship to the host verbatim."
  }
}

run "log_alerts" {
  command = plan

  assert {
    condition = alltrue([
      strcontains(local.loki_rules, "AppErrorSpike"),
      strcontains(local.loki_rules, "NginxErrorSpike"),
      strcontains(local.loki_rules, "NginxUpstreamRefused"),
    ])
    error_message = "Loki alerts on what the applications logged, on 5xx at nginx, and on an upstream that never answered - the case ContainerDown cannot see."
  }

  assert {
    condition     = aws_s3_object.host_config["logging/loki/rules/fake/application.yml"].content == local.loki_rules
    error_message = "The rendered rules ship to the host verbatim."
  }

  # The tenant directory is the part that fails silently: Loki's local rule
  # storage reads <directory>/<tenant>/<namespace>, and with auth_enabled false
  # the tenant is literally "fake".
  assert {
    condition     = endswith(aws_s3_object.host_config["logging/loki/rules/fake/application.yml"].key, "/loki/rules/fake/application.yml")
    error_message = "Rules must land in the fake tenant directory or Loki's ruler loads nothing and stays quiet about it."
  }

  assert {
    condition = alltrue([
      strcontains(local.loki_config, "ruler:"),
      strcontains(local.loki_config, "directory: /loki/rules"),
      strcontains(local.loki_config, "alertmanager_url: http://alertmanager:${var.logging.alertmanager_port}"),
    ])
    error_message = "Loki's ruler reads /loki/rules and hands anything firing to the Alertmanager on the compose network."
  }

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "loki/rules/fake")
    error_message = "The bootstrap creates the tenant directory, so the sync lands in a directory the loki user owns."
  }
}

run "alert_thresholds_are_configurable" {
  command = plan

  variables {
    alert_rules = {
      container_memory_percent = 70
      log_error_rate           = 5
      nginx_5xx_rate           = 2
      log_rule_window          = "5m"
    }
  }

  assert {
    condition = alltrue([
      strcontains(local.prometheus_rules, "> 70"),
      strcontains(local.loki_rules, "[5m]"),
      strcontains(local.loki_rules, "> 5"),
      strcontains(local.loki_rules, "> 2"),
    ])
    error_message = "Both rule files take their window and thresholds from var.alert_rules."
  }
}

run "json_log_services" {
  command = plan

  assert {
    condition     = local.logging_json_services == "nginx"
    error_message = "nginx is always parsed as JSON (its access log format is), even with json_log_services empty."
  }

  assert {
    condition     = strcontains(local.alloy_config, "{service=~")
    error_message = "The parse branch has to be gated by a stream selector, so a plain-text line is never force-parsed."
  }
}

run "json_log_services_extended" {
  command = plan

  variables {
    logging = { json_log_services = ["wallet"] }
  }

  assert {
    condition     = local.logging_json_services == "nginx|wallet"
    error_message = "logging.json_log_services must widen the JSON parse branch to that service."
  }

  assert {
    condition     = strcontains(local.alloy_config, "nginx|wallet")
    error_message = "The widened list must reach the collector config, not just the local."
  }
}

# -----------------------------------------------------------------------------
# Retention and budgets reach the rendered configs
# -----------------------------------------------------------------------------

run "retention" {
  command = plan

  assert {
    condition     = strcontains(local.loki_config, "retention_period: ${var.logging.loki_retention_days * 24}h")
    error_message = "Loki's compactor, not a cron job, is what bounds the log volume."
  }

  assert {
    condition     = strcontains(local.loki_config, "retention_enabled: true")
    error_message = "Retention without delete_request_store/retention_enabled is a number on paper."
  }

  assert {
    condition     = strcontains(local.loki_config, "selector: ")
    error_message = "The shorter per-stream retention (journald, nginx) must be in the config while system_retention_days < loki_retention_days."
  }

  assert {
    condition     = strcontains(local.loki_config, "ingestion_rate_mb: ${var.logging.loki_ingestion_rate_mb}")
    error_message = "The ingest budget has to be enforced by Loki, since the producer is a docker tail it cannot throttle."
  }

  assert {
    condition     = strcontains(local.docker_compose, "--storage.tsdb.retention.size=${var.logging.prometheus_retention_size}")
    error_message = "Prometheus needs a byte cap as well as an age cap on a 20 GB shared volume."
  }
}

run "retention_shared_for_every_stream" {
  command = plan

  variables {
    logging = { system_retention_days = 14 }
  }

  assert {
    condition     = !strcontains(local.loki_config, "retention_stream")
    error_message = "When the system streams keep logs as long as everything else, the per-stream override disappears."
  }
}

# -----------------------------------------------------------------------------
# nginx: the one door in and the allow list in front of it
# -----------------------------------------------------------------------------

run "nginx_vhost_defaults_to_loopback" {
  command = plan

  variables {
    logging = { allowed_cidrs = [] }
  }

  assert {
    condition     = strcontains(local.nginx_conf, "server_name dev-grafana.nomaos.com;")
    error_message = "Grafana is served from logging.grafana_subdomain through nginx, like every other dev host."
  }

  assert {
    condition     = strcontains(local.nginx_conf, "allow 127.0.0.1;") && strcontains(local.nginx_conf, "deny all;")
    error_message = "An empty logging.allowed_cidrs must mean localhost-only, not everyone."
  }

  assert {
    condition     = strcontains(local.nginx_conf, "log_format agrovesto_json")
    error_message = "The access log has to be JSON on stdout for the collector to index it."
  }

  assert {
    condition     = strcontains(local.nginx_conf, "proxy_read_timeout 300s;")
    error_message = "A LogQL query across two weeks of logs must not be killed by a 60s proxy timeout."
  }

  assert {
    condition     = !strcontains(local.nginx_conf, "proxy_pass http://loki")
    error_message = "Loki is never proxied: it stays loopback-only and Grafana reaches it on the docker network."
  }
}

run "nginx_allowlist" {
  command = plan

  variables {
    logging   = { allowed_cidrs = ["203.0.113.10/32", "197.0.0.0/16"] }
    sonarqube = { allowed_cidrs = ["203.0.113.10/32", "197.0.0.0/16"] }
  }

  assert {
    condition     = strcontains(local.nginx_conf, "allow 203.0.113.10/32;") && strcontains(local.nginx_conf, "allow 197.0.0.0/16;")
    error_message = "Each allowed_cidrs entry must become an nginx allow line."
  }

  assert {
    # Grafana and SonarQube replace their loopback fallback with the explicit
    # list. The one remaining loopback allow belongs to the separate, internal
    # Vault vhost while OIDC is disabled.
    condition     = length(regexall("allow 127\\.0\\.0\\.1;", local.nginx_conf)) == 1
    error_message = "An explicit Grafana/SonarQube allowlist replaces their loopback fallback; only the internal Vault vhost keeps its loopback allow."
  }

  assert {
    condition     = length(regexall("allow 203\\.0\\.113\\.10/32;", local.nginx_conf)) == 2
    error_message = "Both gated vhosts (Grafana and SonarQube) receive the allow list, not just one of them."
  }
}

# -----------------------------------------------------------------------------
# cloud-init: what the host actually does with all this
# -----------------------------------------------------------------------------

run "bootstrap" {
  command = plan

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "aws s3 sync \"s3://$${host_config_bucket}/")
    error_message = "Configs are synced from the config bucket, which is why they never touch instance user data."
  }

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "format_and_mount \"$${logging_root}\"")
    error_message = "The log volume is mounted at the same path the compose file bind-mounts from, whether or not it was attached."
  }

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "Storage=persistent")
    error_message = "journald has to be persistent or the host journal is a RAM buffer Alloy cannot read across a reboot."
  }

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "\"max-size\": \"$${logging.docker_log_max_size}\"")
    error_message = "Docker's own log rotation is capped daemon-wide, because those files are what the collector tails."
  }

  assert {
    condition     = !strcontains(file("${path.module}/user_data.sh.tftpl"), "amazon-cloudwatch-agent")
    error_message = "No CloudWatch agent: logs are collected, stored and queried on this host only."
  }

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "GRAFANA_ADMIN_PASSWORD=%s")
    error_message = "Grafana's password is appended to the compose .env by the bootstrap, which is the only place it is written."
  }
}

# -----------------------------------------------------------------------------
# the instance that syncs its config must be the instance carrying that role
# -----------------------------------------------------------------------------

run "host_role" {
  command = plan

  assert {
    condition     = aws_instance.app.iam_instance_profile == aws_iam_instance_profile.ec2.name
    error_message = "The boot-time config sync is an S3 call, so the instance has to run with the role that grants it."
  }

  assert {
    condition = (
      aws_iam_instance_profile.ec2.role == aws_iam_role.ec2.name &&
      aws_iam_role_policy_attachment.ssm.role == aws_iam_role.ec2.name &&
      aws_iam_role_policy_attachment.ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    )
    error_message = "Profile and SSM attachment hang off the one dev EC2 role; Session Manager (the tunnel fallback) depends on it."
  }

  assert {
    condition = (
      aws_iam_role.ec2.name == "${local.name}-ec2-role" &&
      aws_iam_role_policy.ec2.name == "${local.name}-ec2-policy" &&
      aws_iam_instance_profile.ec2.name == "${local.name}-ec2-profile"
    )
    error_message = "Role, policy and profile keep the local.name prefix, so the dev account's objects stay attributable."
  }

  # The claim this stack makes is "no AWS-native logging", and the way to regress
  # it silently is to give a container the awslogs driver or install the agent.
  # The policy document itself cannot be asserted on - mock_provider only knows
  # what override_data pins - so the guard lives where it is plan-known.
  assert {
    condition     = !strcontains(local.docker_compose, "awslogs") && !strcontains(file("${path.module}/user_data.sh.tftpl"), "awslogs")
    error_message = "No service may opt into the awslogs driver: that would ship app logs to CloudWatch, which this stack deliberately does not do."
  }

  # The collector reads the daemon's own json-file logs, so the rotation config and
  # the driver have to stay as user_data writes them.
  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "\"log-driver\": \"json-file\"")
    error_message = "The daemon has to keep json-file logs - Alloy tails those files instead of a per-service driver."
  }
}

# -----------------------------------------------------------------------------
# logging.enabled = false takes the whole thing out
# -----------------------------------------------------------------------------

run "disabled" {
  command = plan

  variables {
    logging = { enabled = false }
  }

  assert {
    condition     = length(aws_ebs_volume.logging) == 0 && length(aws_volume_attachment.logging) == 0
    error_message = "Nothing is provisioned for logging when it is switched off - including the volume."
  }

  # The bucket itself does NOT go away with the logging stack: compose,
  # nginx.conf, the per-API blue/green slot files and init-dbs.sql come from it
  # on every boot, logging or not.
  assert {
    condition = (
      length(aws_s3_object.host_config) == 5 &&
      alltrue([
        for k in ["compose/docker-compose.yml", "nginx/nginx.conf", "nginx/nomaos_api-active.conf", "nginx/wallet_api-active.conf", "scripts/init-dbs.sql"] :
        contains(keys(aws_s3_object.host_config), k)
      ])
    )
    error_message = "With logging off the bucket keeps exactly the five always-needed files (compose, nginx.conf, one slot file per opted-in API, init-dbs.sql)."
  }

  assert {
    condition     = !strcontains(local.docker_compose, "container_name: agrovesto-grafana") && !strcontains(local.docker_compose, "container_name: agrovesto-node-exporter") && !strcontains(local.docker_compose, "container_name: agrovesto-tempo")
    error_message = "The compose project must not carry any observability container."
  }

  assert {
    condition     = !strcontains(local.docker_compose, "OTEL_EXPORTER_OTLP_ENDPOINT")
    error_message = "With logging off there is no Alloy to receive spans, so the APIs keep exactly their own env — no OTEL block."
  }

  assert {
    condition     = !strcontains(local.nginx_conf, "dev-grafana")
    error_message = "No Grafana vhost, so no new listener on port 80."
  }

  assert {
    condition     = length(aws_security_group.ec2.ingress) == 3
    error_message = "The security group is untouched: the stack adds no ingress rule, it rides on nginx's port 80."
  }
}
