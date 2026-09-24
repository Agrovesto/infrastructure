locals {
  name = "${var.project}-monitoring"

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Stack       = "monitoring"
    },
    var.tags
  )

  # Single-AZ on purpose: EFS One Zone is ~45% cheaper than Regional and the
  # whole monitoring stack is non-critical infrastructure. Every task is pinned
  # to the first private subnet so the mount target is reachable.
  monitor_subnet_id = sort(data.aws_subnets.private.ids)[0]

  sizing   = var.service_sizing
  param    = "/${local.name}"
  dns_name = "monitoring.internal"

  images = {
    prometheus   = "prom/prometheus:${var.prometheus_version}"
    alertmanager = "prom/alertmanager:${var.alertmanager_version}"
    loki         = "grafana/loki:${var.loki_version}"
    tempo        = "grafana/tempo:${var.tempo_version}"
    grafana      = "grafana/grafana-oss:${var.grafana_version}"
    alloy        = "grafana/alloy:${var.alloy_version}"
    blackbox     = "prom/blackbox-exporter:${var.blackbox_version}"
    pushgateway  = "prom/pushgateway:${var.pushgateway_version}"
    awscli       = "public.ecr.aws/aws-cli/aws-cli:${var.awscli_version}"
    mssql        = "python:${var.python_version}"
    collector    = "python:${var.python_version}"
    budget       = "python:${var.python_version}"
  }

  # Internal service endpoints (Cloud Map private DNS).
  endpoints = {
    prometheus   = "http://prometheus.${local.dns_name}:9090"
    alertmanager = "http://alertmanager.${local.dns_name}:9093"
    loki         = "http://loki.${local.dns_name}:3100"
    tempo        = "http://tempo.${local.dns_name}:3200"
    grafana      = "http://grafana.${local.dns_name}:3000"
    alloy        = "http://alloy.${local.dns_name}"
    blackbox     = "http://blackbox.${local.dns_name}:9115"
    pushgateway  = "http://pushgateway.${local.dns_name}:9091"
  }

  grafana_host = "${var.grafana_subdomain}.${var.domain_name}"

  grafana_github_credentials_set = [
    var.grafana_github_client_id != "",
    nonsensitive(var.grafana_github_client_secret != ""),
  ]
  grafana_github_configuration_valid = alltrue(local.grafana_github_credentials_set) || !anytrue(local.grafana_github_credentials_set)
  grafana_github_sso_enabled         = alltrue(local.grafana_github_credentials_set)
  grafana_github_parameter_names = {
    client_id     = "${local.param}/grafana/github-client-id"
    client_secret = "${local.param}/grafana/github-client-secret"
  }

  # Config files are rendered here, published to SSM and pulled by a small
  # aws-cli init container into each task's EFS volume (see config.tf).
  # Config-fetch command: one parameter per file, written as <mount>/config/<rel>.
  config_fetch_command = [
    "set -euo pipefail",
    "mkdir -p /config/config",
    "aws s3 sync \"s3://$CONFIG_BUCKET/config/$CONFIG_COMPONENT\" /config/config --delete --region \"$AWS_REGION\"",
  ]

  # One awslogs config per component, all in the stack's log group.
  log_components = ["prometheus", "alertmanager", "loki", "tempo", "grafana", "alloy", "blackbox", "pushgateway"]

  log_config = { for k in local.log_components : k => {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.monitoring.name
      awslogs-region        = var.aws_region
      awslogs-stream-prefix = k
    }
  } }

  init_container = {
    name      = "config"
    image     = local.images.awscli
    essential = false
    user      = "0"
    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "CONFIG_BUCKET", value = aws_s3_bucket.config.bucket },
    ]
    command = ["/bin/sh", "-c", join("\n", local.config_fetch_command)]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.monitoring.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "config"
      }
    }
    mountPoints = [{ sourceVolume = "data", containerPath = "/config", readOnly = false }]
  }

  init_containers = {
    for component in ["prometheus", "loki", "tempo", "grafana", "rds", "collector"] :
    component => merge(local.init_container, {
      environment = concat(local.init_container.environment, [{ name = "CONFIG_COMPONENT", value = component }])
    })
  }

  # --- Prometheus ------------------------------------------------------------------

  # One static_configs entry per probe, carrying the probe name as a label so
  # alerts and dashboards can group by service without relabel rules.
  prometheus_probe_targets = join("\n", [
    for name, url in var.probe_targets :
    "          - targets: [\"${url}\"]\n            labels:\n              probe: ${name}"
  ])

  prometheus_config = <<-EOT
    global:
      scrape_interval: ${var.probe_interval_seconds}s
      scrape_timeout: 10s
      evaluation_interval: 60s
      external_labels:
        stack: monitoring
        env: ${var.environment}

    rule_files:
      - /prometheus/config/rules/*.yml

    alerting:
      alertmanagers:
        - static_configs:
            - targets: ["alertmanager.${local.dns_name}:9093"]

    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ["localhost:9090"]

      - job_name: pushgateway
        honor_labels: true
        static_configs:
          - targets: ["pushgateway.${local.dns_name}:9091"]

      - job_name: alloy
        static_configs:
          - targets: ["alloy.${local.dns_name}:12345"]

      - job_name: loki
        static_configs:
          - targets: ["loki.${local.dns_name}:3100"]

      - job_name: tempo
        static_configs:
          - targets: ["tempo.${local.dns_name}:3200"]

      - job_name: grafana
        static_configs:
          - targets: ["grafana.${local.dns_name}:3000"]

      - job_name: alertmanager
        static_configs:
          - targets: ["alertmanager.${local.dns_name}:9093"]

      - job_name: blackbox
        static_configs:
          - targets: ["blackbox.${local.dns_name}:9115"]

      - job_name: uptime
        metrics_path: /probe
        params:
          module: [http_2xx]
        static_configs:
    ${local.prometheus_probe_targets}
        relabel_configs:
          - source_labels: [__address__]
            target_label: __param_target
          - source_labels: [__param_target]
            target_label: instance
          - target_label: __address__
            replacement: blackbox.${local.dns_name}:9115
  EOT

  prometheus_platform_rules = <<-EOT
    groups:
      - name: uptime
        rules:
          - alert: ProbeFailing
            expr: probe_success == 0
            for: 2m
            labels:
              severity: critical
            annotations:
              summary: "{{ $labels.probe }} is not responding"
              description: "{{ $labels.instance }} has failed for {{ $value }} minutes"

          - alert: ProbeSlow
            expr: probe_duration_seconds > 3
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "{{ $labels.probe }} is slow"
              description: "{{ $labels.instance }} responds in {{ $value }}s"

          - alert: TlsCertificateExpiring
            expr: probe_ssl_earliest_cert_expiry - time() < ${var.tls_expiry_warning_days * 86400}
            for: 1h
            labels:
              severity: warning
            annotations:
              summary: "TLS certificate for {{ $labels.probe }} expires soon"

      - name: platform
        rules:
          - alert: MonitoringTargetDown
            expr: up == 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "{{ $labels.job }} target is down"
              description: "{{ $labels.instance }} has been unreachable for 5m"
  EOT

  prometheus_rds_rules = <<-EOT
    groups:
      - name: database
        rules:
          - alert: MssqlUnreachable
            expr: mssql_up == 0
            for: 15m
            labels:
              severity: critical
            annotations:
              summary: "The prod SQL Server could not be reached by the metrics task"
              description: "job=mssql target {{ $labels.instance }}"

          - alert: MssqlMetricsStale
            expr: time() - mssql_scrape_timestamp_seconds > 10800
            for: 30m
            labels:
              severity: warning
            annotations:
              summary: "No SQL Server metrics for over 3h"

          - alert: MssqlLowDiskSpace
            expr: mssql_volume_available_bytes / mssql_volume_total_bytes < 0.15
            for: 30m
            labels:
              severity: warning
            annotations:
              summary: "RDS volume {{ $labels.mount }} is more than 85% full"
              description: "{{ $value | humanizePercentage }} of the volume is free"

          - alert: MssqlBlockedSessions
            expr: mssql_blocked_sessions > 5
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "{{ $value }} sessions are blocked on the prod SQL Server"

          - alert: MssqlDeadlockSpike
            expr: increase(mssql_deadlocks_total[15m]) > 5
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Deadlocks on the prod SQL Server"
              description: "{{ $value }} deadlocks in the last 15m"

          - alert: MssqlDatabaseNearSizeLimit
            expr: mssql_database_size_bytes > ${var.mssql_database_size_warning_bytes}
            for: 15m
            labels:
              severity: critical
            annotations:
              summary: "Database {{ $labels.db }} is nearing the SQL Server Express 10 GB cap"
              description: "{{ $value | humanize1024 }}B in use; writes fail at 10 GB. Snapshot, restore to sqlserver-web/standard-se and rename to keep the endpoint."
  EOT

  prometheus_ecs_rules = <<-EOT
    groups:
      - name: ecs
        rules:
          - alert: EcsMetricsMissing
            expr: absent(ecs_up)
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "The ECS collector has not reported for 10m"

          - alert: EcsCollectorFailing
            expr: ecs_up == 0
            for: 10m
            labels:
              severity: critical
            annotations:
              summary: "The ECS collector cannot read the cluster state"

          - alert: EcsServiceShortOfTasks
            expr: ecs_service_running_count < ecs_service_desired_count
            for: 10m
            labels:
              severity: critical
            annotations:
              summary: "{{ $labels.service }} is running fewer tasks than it wants"
              description: "{{ $value }} task(s) missing on {{ $labels.cluster }}"

          - alert: EcsServiceTasksPending
            expr: ecs_service_pending_count > 0
            for: 15m
            labels:
              severity: warning
            annotations:
              summary: "{{ $labels.service }} has tasks stuck in PENDING for 15m"

          - alert: EcsDeploymentFailed
            expr: ecs_service_deployment_failed == 1
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "{{ $labels.service }} deployment failed or rolled back"

          - alert: EcsTasksStopping
            expr: ecs_stopped_tasks{stop_code=~"TaskFailed.*|CannotPullContainer.*|OutOfMemoryError.*"} > 0
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "{{ $labels.service }} tasks are stopping with {{ $labels.stop_code }}"

          - alert: EcsLogShipperStalled
            expr: time() - ecs_logs_scrape_timestamp_seconds > 900
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "ECS log shipping into Loki has stalled"
  EOT

  prometheus_cost_rules = <<-EOT
    groups:
      - name: cost
        rules:
          - alert: BudgetThresholdExceeded
            expr: budget_utilization_ratio > ${var.budget_alert_ratio}
            for: 15m
            labels:
              severity: warning
            annotations:
              summary: "Projected month-end spend passed ${var.budget_alert_ratio * 100}% of the monthly budget"
              description: "budget_utilization_ratio = {{ $value }}"

          - alert: CostReportStale
            expr: time() - cost_report_timestamp_seconds > 129600
            for: 30m
            labels:
              severity: warning
            annotations:
              summary: "The daily cost report has not run for over 36h"
  EOT

  # --- Alertmanager ----------------------------------------------------------------

  # Receivers are rendered only for the channels that are configured, so a
  # stack with no secrets still applies and simply records alerts in its UI.
  # SNS: publishes to the prod alerts topic (prod/sns.tf), signing with the ECS
  # task role (sigv4 default credential chain), so no keys are configured.
  alertmanager_sns_topic_arn = var.alertmanager_sns_topic != "" ? "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.alertmanager_sns_topic}" : ""

  alertmanager_receivers = join("\n", concat(
    [
      "  - name: default",
    ],
    local.alertmanager_sns_topic_arn != "" ? [
      "    sns_configs:",
      "      - topic_arn: ${local.alertmanager_sns_topic_arn}",
      "        sigv4:",
      "          region: ${var.aws_region}",
      "        subject: '[{{ .Status | toUpper }}] {{ .CommonLabels.alertname }}'",
      "        send_resolved: true",
    ] : [],
    nonsensitive(var.alertmanager_webhook_url != "") ? [
      "    webhook_configs:",
      "      - url_file: /alertmanager/config/webhook-url",
      "        send_resolved: true",
    ] : [],
    var.alert_email != "" && var.alert_smtp_host != "" ? [
      "    email_configs:",
      "      - to: ${var.alert_email}",
      "        from: ${var.alert_smtp_from}",
      "        smarthost: ${var.alert_smtp_host}:${var.alert_smtp_port}",
      "        auth_username: ${var.alert_smtp_user}",
    ] : [],
    var.alert_email != "" && var.alert_smtp_host != "" && nonsensitive(var.alert_smtp_password != "") ? [
      "        auth_password_file: /alertmanager/config/smtp-password",
    ] : [],
    var.alert_email != "" && var.alert_smtp_host != "" ? [
      "        send_resolved: true",
    ] : [],
  ))

  alertmanager_config = <<-EOT
    global:
      resolve_timeout: 5m

    route:
      receiver: default
      group_by: [alertname, probe]
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      routes:
        - matchers: ['severity="critical"']
          receiver: default
          repeat_interval: 1h

    inhibit_rules:
      - source_matchers: [severity="critical"]
        target_matchers: [severity="warning"]
        equal: [alertname, probe]

    receivers:
    ${local.alertmanager_receivers}
  EOT

  # --- Loki ------------------------------------------------------------------------

  loki_config = <<-EOT
    auth_enabled: false

    server:
      http_listen_port: 3100
      log_level: warn

    common:
      instance_addr: 127.0.0.1
      path_prefix: /loki
      storage:
        filesystem:
          chunks_directory: /loki/chunks
          rules_directory: /loki/config/rules
      replication_factor: 1
      ring:
        kvstore:
          store: inmemory

    schema_config:
      configs:
        - from: 2024-01-01
          store: tsdb
          object_store: filesystem
          schema: v13
          index:
            prefix: index_
            period: 24h

    limits_config:
      retention_period: ${var.logs_retention_hours}h
      allow_structured_metadata: true
      max_query_series: 5000

    compactor:
      working_directory: /loki/compactor
      retention_enabled: true
      delete_request_store: filesystem

    ruler:
      storage:
        type: local
        local:
          directory: /loki/config/rules
      rule_path: /loki/rules-temp
      alertmanager_url: ${local.endpoints.alertmanager}
      enable_api: true
      ring:
        kvstore:
          store: inmemory

    analytics:
      reporting_enabled: false
  EOT

  # LogQL alerts on application/ALB logs once services push them (see README).
  loki_rules = <<-EOT
    groups:
      - name: application-logs
        rules:
          - alert: ApplicationErrorSpike
            expr: sum(rate({source="app"} |= "level=error" [10m])) > 1
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "Error-rate spike in application logs"
  EOT

  # --- Tempo -----------------------------------------------------------------------

  tempo_config = <<-EOT
    stream_over_http_enabled: true

    server:
      http_listen_port: 3200
      log_level: warn

    distributor:
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318

    ingester:
      max_block_duration: 5m

    compactor:
      compaction:
        block_retention: ${var.traces_retention_hours}h

    storage:
      trace:
        backend: local
        local:
          path: /tempo/blocks
        wal:
          path: /tempo/wal

    metrics_generator:
      registry:
        external_labels:
          source: tempo
      storage:
        path: /tempo/generator/wal
        remote_write:
          - url: ${local.endpoints.prometheus}/api/v1/write
      processor:
        span_metrics: {}

    overrides:
      defaults:
        metrics_generator:
          processors:
            - span-metrics
  EOT

  # --- Alloy: single OTLP + Loki-push ingestion gateway -----------------------------

  alloy_config = <<-EOT
    logging {
      level  = "warn"
      format = "logfmt"
    }

    // Logs: Loki push API (Fluent Bit/FireLens, Promtail, or the app itself).
    loki.source.api "push" {
      http {
        listen_address = "0.0.0.0"
        listen_port    = 3100
      }

      labels      = { source = "loki-push" }
      forward_to  = [loki.write.default.receiver]
    }

    loki.write "default" {
      endpoint {
        url = "${local.endpoints.loki}/loki/api/v1/push"
      }
    }

    // Traces + metrics: OTLP from the OpenTelemetry SDK/SDK-side car in each service.
    otelcol.receiver.otlp "default" {
      grpc {
        endpoint = "0.0.0.0:4317"
      }

      http {
        endpoint = "0.0.0.0:4318"
      }

      output {
        metrics = [otelcol.exporter.prometheus.default.input]
        logs    = [otelcol.exporter.loki.default.input]
        traces  = [otelcol.exporter.otlp.tempo.input]
      }
    }

    otelcol.exporter.otlp "tempo" {
      client {
        endpoint = "tempo.${local.dns_name}:4317"

        tls {
          insecure = true
        }
      }
    }

    otelcol.exporter.loki "default" {
      forward_to = [loki.write.default.receiver]
    }

    otelcol.exporter.prometheus "default" {
      forward_to = [prometheus.remote_write.default.receiver]
    }

    prometheus.remote_write "default" {
      endpoint {
        url = "${local.endpoints.prometheus}/api/v1/write"
      }
    }

    // Alloy's own metrics, scraped by Prometheus.
    prometheus.exporter.self "alloy" {
    }

    prometheus.scrape "alloy" {
      targets         = prometheus.exporter.self.alloy.targets
      forward_to      = [prometheus.remote_write.default.receiver]
      scrape_interval = "60s"
    }
  EOT

  # --- blackbox exporter -----------------------------------------------------------

  blackbox_config = <<-EOT
    modules:
      http_2xx:
        prober: http
        timeout: 10s
        http:
          preferred_ip_protocol: ip4
          valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
          follow_redirects: true
          fail_if_not_ssl: true

      tcp_connect:
        prober: tcp
        timeout: 5s
  EOT

  # --- Grafana provisioning --------------------------------------------------------

  grafana_datasources = <<-EOT
    apiVersion: 1

    datasources:
      - name: Prometheus
        uid: prometheus
        type: prometheus
        access: proxy
        url: ${local.endpoints.prometheus}
        isDefault: true
        jsonData:
          timeInterval: ${var.probe_interval_seconds}s

      - name: Loki
        uid: loki
        type: loki
        access: proxy
        url: ${local.endpoints.loki}
        jsonData:
          maxLines: 1000
          derivedFields:
            - name: TraceID
              matcherRegex: "trace_id=(\\w+)"
              datasourceUid: tempo
              url: "$${__value.raw}"

      - name: Tempo
        uid: tempo
        type: tempo
        access: proxy
        url: ${local.endpoints.tempo}
        jsonData:
          tracesToLogsV2:
            datasourceUid: loki
            filterByTraceID: true
  EOT

  grafana_dashboards_provider = <<-EOT
    apiVersion: 1

    providers:
      - name: agrovesto
        orgId: 1
        folder: Agrovesto
        type: file
        disableDeletion: false
        updateIntervalSeconds: 30
        allowUiUpdates: true
        options:
          path: /var/lib/grafana/config/dashboards
          foldersFromFilesStructure: false
  EOT
}
