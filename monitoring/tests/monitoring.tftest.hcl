# Component task definitions, services, Grafana ingress and the cost pipeline.

mock_provider "aws" {
  # Mock values are generated strings, but the provider validates several
  # attributes as ARNs. Pin them so an apply run reaches the assertions.
  mock_resource "aws_ecs_cluster" {
    defaults = {
      arn = "arn:aws:ecs:eu-west-1:123456789012:cluster/agrovesto-monitoring"
    }
  }
  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:eu-west-1:123456789012:task-definition/agrovesto-monitoring-report:1"
    }
  }
  mock_resource "aws_efs_file_system" {
    defaults = {
      arn = "arn:aws:elasticfilesystem:eu-west-1:123456789012:file-system/fs-0123456789abcdef0"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/agrovesto-monitoring-task"
    }
  }
  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/agrovesto-monitoring-grafana/1234567890abcdef"
    }
  }
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::agrovesto-monitoring-config"
    }
  }
  mock_resource "aws_service_discovery_service" {
    defaults = {
      arn = "arn:aws:servicediscovery:eu-west-1:123456789012:service/srv-0123456789abcdef"
    }
  }
  mock_resource "aws_ses_domain_dkim" {
    defaults = {
      dkim_tokens = ["mock-dkim-token-1", "mock-dkim-token-2", "mock-dkim-token-3"]
    }
  }
  mock_resource "aws_ses_domain_identity" {
    defaults = {
      arn = "arn:aws:ses:eu-west-1:123456789012:identity/nomaos.com"
    }
  }
  mock_resource "aws_ssm_parameter" {
    defaults = {
      arn     = "arn:aws:ssm:eu-west-1:123456789012:parameter/agrovesto/monitoring/grafana-admin"
      version = 1
    }
  }
  mock_data "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:loadbalancer/app/agrovesto-prod/1234567890abcdef"
    }
  }
  mock_data "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:listener/app/agrovesto-prod/1234567890abcdef/1234567890abcdef"
    }
  }
}

# The cost resources use the us-east-1 provider alias; without a mock for it the
# test would configure the real provider and ask for credentials.
mock_provider "aws" {
  alias = "us_east_1"
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "221434544570"
    arn        = "arn:aws:iam::221434544570:root"
  }
}

override_data {
  target = data.aws_region.current
  values = { name = "eu-west-1" }
}

override_data {
  target = data.aws_vpc.prod
  values = {
    id         = "vpc-0prod"
    cidr_block = "10.0.0.0/16"
  }
}

override_data {
  target = data.aws_subnets.private
  values = { ids = ["subnet-0private1", "subnet-0private2"] }
}

override_data {
  target = data.aws_subnet.monitoring
  values = {
    id                = "subnet-0private1"
    availability_zone = "eu-west-1a"
    cidr_block        = "10.0.11.0/24"
  }
}

override_data {
  target = data.aws_lb.main
  values = {
    arn      = "arn:aws:elasticloadbalancing:eu-west-1:221434544570:loadbalancer/app/agrovesto-prod-alb/1234"
    dns_name = "agrovesto-prod-alb-1234.eu-west-1.elb.amazonaws.com"
    zone_id  = "Z32O12XQLNTSW2"
  }
}

override_data {
  target = data.aws_lb_listener.https
  values = { arn = "arn:aws:elasticloadbalancing:eu-west-1:221434544570:listener/app/agrovesto-prod-alb/1234/5678" }
}

override_data {
  target = data.aws_security_group.alb
  values = { id = "sg-0alb" }
}

override_data {
  target = data.aws_db_instance.mssql
  values = {
    address = "migration-prod.abc123.eu-west-1.rds.amazonaws.com"
    port    = 1433
    # The adopted migration-prod has no RDS-managed master secret
    # (mssql_manage_master_user_password stays false in prod/), so the data
    # source returns none and var.mssql_secret_name below carries the secret.
    master_user_secret = []
  }
}

override_data {
  target = data.aws_route53_zone.main
  values = {
    zone_id = "Z0123456789ABCDEF"
    name    = "nomaos.com."
  }
}

variables {
  domain_name            = "nomaos.com"
  monthly_budget_usd     = 250
  enable_cost_monitoring = true
  mssql_secret_name      = "arn:aws:secretsmanager:eu-west-1:221434544570:secret:nomaosDBcredentials-TEST01" # ggignore - test fixture, not a credential
}

run "components_run_on_fargate_with_their_own_state" {
  command = plan

  assert {
    condition     = aws_ecs_service.prometheus.launch_type == "FARGATE" && aws_ecs_service.grafana.launch_type == "FARGATE"
    error_message = "Stateful components must run on on-demand Fargate."
  }

  assert {
    condition     = aws_ecs_service.loki[0].launch_type == "FARGATE" && aws_ecs_service.tempo[0].launch_type == "FARGATE"
    error_message = "Loki and Tempo must not be interrupted by Spot reclaims."
  }

  assert {
    condition     = contains(aws_ecs_task_definition.prometheus.requires_compatibilities, "FARGATE") && aws_ecs_task_definition.prometheus.network_mode == "awsvpc"
    error_message = "Prometheus must run as an awsvpc Fargate task."
  }

  assert {
    condition     = aws_ecs_service.prometheus.enable_execute_command && aws_ecs_task_definition.prometheus.cpu != null
    error_message = "Every component must be reachable with ECS Exec."
  }

  assert {
    condition     = strcontains(jsonencode(aws_ecs_task_definition.prometheus.container_definitions), "awslogs-group")
    error_message = "Task output must reach CloudWatch Logs."
  }

  assert {
    condition     = strcontains(jsonencode(aws_ecs_task_definition.edge.container_definitions), "secret") == false
    error_message = "Config is fetched from S3 and EFS, not injected as task secrets."
  }
}

run "dashboards_and_datasources_are_provisioned" {
  command = plan

  assert {
    condition     = strcontains(local.grafana_datasources, "loki") && strcontains(local.grafana_datasources, "tempo")
    error_message = "Grafana must ship with the Prometheus, Loki and Tempo datasources."
  }

  assert {
    condition     = length(regexall("uid: (prometheus|loki|tempo)", local.grafana_datasources)) == 3
    error_message = "Datasource uids must stay stable for the provisioned dashboards."
  }

  assert {
    condition     = strcontains(local.grafana_dashboards_provider, "path: /var/lib/grafana/config/dashboards")
    error_message = "Dashboards must be loaded from the provisioned directory."
  }
}

run "production_grafana_github_sso_maps_team_roles_and_uses_ssm" {
  command = apply

  variables {
    grafana_github_client_id     = "test-grafana-client-id"
    grafana_github_client_secret = "not-a-real-secret" # ggignore - test fixture
  }

  assert {
    condition     = length(aws_ssm_parameter.grafana_github_client_id) == 1 && length(aws_ssm_parameter.grafana_github_client_secret) == 1
    error_message = "A complete OAuth credential pair must be stored as SSM SecureStrings."
  }

  assert {
    condition = (
      aws_ssm_parameter.grafana_github_client_id[0].type == "SecureString" &&
      aws_ssm_parameter.grafana_github_client_secret[0].type == "SecureString"
    )
    error_message = "Neither OAuth credential may be embedded as a plain task-definition value."
  }

  assert {
    condition = alltrue([
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "GF_AUTH_GITHUB_ENABLED"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "GF_AUTH_GITHUB_CLIENT_SECRET"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "Agrovesto"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "user:email,read:org"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "https://grafana.nomaos.com"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "GF_AUTH_GITHUB_ROLE_ATTRIBUTE_PATH"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "@Agrovesto/infrastructure"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "@Agrovesto/team-leads"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "@Agrovesto/backend"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "@Agrovesto/frontend"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "@Agrovesto/mobile"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "'Admin'"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "'Editor'"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "'Viewer'"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "GF_AUTH_GITHUB_ROLE_ATTRIBUTE_STRICT"),
      strcontains(aws_ecs_task_definition.grafana.container_definitions, "GITHUB_OAUTH_CONFIG_VERSION"),
      !strcontains(aws_ecs_task_definition.grafana.container_definitions, "not-a-real-secret"),
    ])
    error_message = "Production Grafana must enable GitHub OAuth, map Agrovesto teams to roles, and reference rather than embed the secret."
  }
}

run "traces_are_exported_as_span_metrics" {
  command = plan

  assert {
    condition     = strcontains(local.tempo_config, "span_metrics") && strcontains(local.tempo_config, "/api/v1/write")
    error_message = "Tempo must generate span metrics and remote-write them to Prometheus."
  }

  assert {
    condition     = strcontains(local.tempo_config, "processors:") && strcontains(local.tempo_config, "span-metrics")
    error_message = "The generator processors must be enabled, otherwise no span metrics are produced."
  }
}

run "grafana_is_reachable_through_the_prod_alb_only" {
  command = plan

  assert {
    condition     = aws_lb_target_group.grafana.port == 3000 && aws_lb_target_group.grafana.target_type == "ip"
    error_message = "Grafana must be an IP target on port 3000."
  }

  assert {
    condition     = aws_lb_target_group.grafana.health_check[0].path == "/api/health"
    error_message = "Health checks must use the Grafana health endpoint."
  }

  assert {
    condition     = aws_lb_listener_rule.grafana.priority == 900
    error_message = "The Grafana listener rule priority drifted."
  }

  assert {
    condition     = aws_route53_record.grafana.name == "grafana.nomaos.com" && aws_route53_record.grafana.type == "A"
    error_message = "Grafana needs an alias record on the public zone."
  }
}

run "exporters_cover_uptime_and_push_metrics" {
  command = plan

  assert {
    condition     = aws_ecs_service.edge.desired_count == 1
    error_message = "The edge group carries the blackbox exporter and must always run."
  }

  assert {
    condition     = strcontains(local.prometheus_config, "job_name: prometheus")
    error_message = "Prometheus must scrape itself."
  }

  assert {
    condition     = strcontains(local.blackbox_config, "http_2xx")
    error_message = "The blackbox module must check for HTTP 2xx."
  }

  assert {
    condition = alltrue([
      strcontains(jsonencode(aws_ecs_task_definition.edge.container_definitions), "grafana/alloy:"),
      strcontains(jsonencode(aws_ecs_task_definition.edge.container_definitions), "prom/alertmanager:"),
      strcontains(jsonencode(aws_ecs_task_definition.edge.container_definitions), "prom/blackbox-exporter:"),
      strcontains(jsonencode(aws_ecs_task_definition.edge.container_definitions), "prom/pushgateway:")
    ])
    error_message = "The edge task must carry all four edge containers."
  }

  assert {
    condition     = strcontains(local.prometheus_platform_rules, "ProbeFailing") && strcontains(local.prometheus_platform_rules, "MonitoringTargetDown")
    error_message = "Uptime and component-health alerts must be part of the platform rules."
  }
}

run "cost_pipeline_is_wired" {
  command = plan

  assert {
    condition     = aws_cur_report_definition.daily[0].report_name == var.cur_report_name
    error_message = "The CUR report name must match the path the report script reads."
  }

  assert {
    condition     = strcontains(aws_ecs_task_definition.budget[0].container_definitions, "CUR_REPORT_NAME") && strcontains(aws_ecs_task_definition.budget[0].container_definitions, var.cur_report_name)
    error_message = "The budget task must read the report the definition delivers."
  }

  assert {
    condition     = strcontains(aws_s3_bucket_policy.cur[0].policy, "billingreports.amazonaws.com")
    error_message = "CUR delivery must be allowed into the bucket."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.cur[0].rule[0].expiration[0].days == 400
    error_message = "Cost reports older than 400 days must expire."
  }

  assert {
    condition     = aws_cloudwatch_event_rule.budget[0].schedule_expression == "cron(15 6 * * ? *)"
    error_message = "The budget job must run daily."
  }

  assert {
    condition     = strcontains(local.prometheus_cost_rules, "BudgetThresholdExceeded") && strcontains(local.prometheus_cost_rules, "CostReportStale")
    error_message = "Budget threshold and staleness alerts must both be defined."
  }
}

run "database_metrics_are_scheduled" {
  command = plan

  assert {
    condition     = length(aws_ecs_task_definition.mssql_metrics) == 1
    error_message = "The SQL Server metrics task must exist when RDS monitoring is on."
  }

  assert {
    # The distribution is python-tds; a PyPI project called "pytds" exists but
    # ships no files, so installing it fails and the task never reaches the
    # collector — the failure this pin now prevents.
    condition     = strcontains(jsonencode(aws_ecs_task_definition.mssql_metrics[0].container_definitions), "python-tds")
    error_message = "The metrics task must install the pure-Python TDS client under its real distribution name."
  }

  assert {
    condition     = aws_cloudwatch_event_rule.mssql[0].schedule_expression == "rate(1 hour)"
    error_message = "The metrics task must run hourly."
  }

  assert {
    condition     = one(aws_cloudwatch_event_target.mssql[0].ecs_target).launch_type == "FARGATE"
    error_message = "The metrics task must run on Fargate."
  }

  assert {
    condition     = aws_iam_role_policy.task.name == "agrovesto-monitoring-task-policy"
    error_message = "The task policy must exist for the metrics task."
  }

  assert {
    condition     = length(aws_iam_role_policy.task_database_secret) == 1
    error_message = "The metrics task needs the policy that reads the database secret."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.task_database_secret[0].policy, "secret:nomaosDBcredentials-TEST01")
    error_message = "The secret policy must be scoped to var.mssql_secret_name — the adopted instance's existing master secret; it has no RDS-managed one."
  }

  assert {
    condition     = strcontains(jsonencode(aws_ecs_task_definition.mssql_metrics[0].container_definitions), "migration-prod.abc123.eu-west-1.rds.amazonaws.com")
    error_message = "DB_HOST must come from the RDS instance data source (managed secrets carry no host)."
  }

  assert {
    condition = (
      strcontains(local.grafana_datasources, "uid: mssql") &&
      strcontains(local.grafana_datasources, "type: mssql") &&
      strcontains(local.grafana_datasources, "migration-prod.abc123.eu-west-1.rds.amazonaws.com:1433") &&
      strcontains(local.grafana_datasources, "$${MSSQL_USER}") &&
      strcontains(local.grafana_datasources, "$${MSSQL_PASSWORD}")
    )
    error_message = "Grafana provisions an MSSQL datasource pointing at the RDS endpoint, with credentials left as environment placeholders ECS fills from the managed secret."
  }

  assert {
    condition = (
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "MSSQL_USER") &&
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), ":username::") &&
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), ":password::")
    )
    error_message = "The Grafana task resolves the secret's username and password keys at start (valueFrom with the :key:: suffix)."
  }

  assert {
    condition     = contains(aws_ecs_service.grafana.network_configuration[0].security_groups, aws_security_group.internal.id)
    error_message = "While the MSSQL datasource is on, Grafana joins the internal SG — the path the RDS instance admits the monitoring stack through."
  }

  assert {
    condition = (
      length(aws_iam_role_policy.execution_database_secret) == 1 &&
      strcontains(aws_iam_role_policy.execution_database_secret[0].policy, "secret:nomaosDBcredentials-TEST01")
    )
    error_message = "Secret resolution for valueFrom runs under the execution role, scoped to the database master secret."
  }

  assert {
    condition = (
      contains(keys(aws_s3_object.config), "grafana/dashboards/database.json") &&
      strcontains(aws_s3_object.config["grafana/dashboards/database.json"].content, "agrovesto-database") &&
      strcontains(aws_s3_object.config["grafana/dashboards/database.json"].content, "mssql_wait_time_seconds_total") &&
      strcontains(aws_s3_object.config["grafana/dashboards/database.json"].content, "mssql_io_read_bytes_total") &&
      strcontains(aws_s3_object.config["grafana/dashboards/database.json"].content, "client_net_address") &&
      strcontains(aws_s3_object.config["grafana/dashboards/database.json"].content, "dm_exec_query_stats") &&
      output.dashboard_uids.database == "agrovesto-database"
    )
    error_message = "The per-database deep-dive dashboard ships with the DMV task that feeds it, including the Performance-Insights-style workload row and the who-is-connected / top-queries live tables."
  }

  assert {
    condition = (
      strcontains(local.prometheus_rds_rules, "MssqlLogSpaceHigh") &&
      strcontains(local.prometheus_rds_rules, "mssql_log_used_bytes / mssql_log_size_bytes > 0.90")
    )
    error_message = "A database using over 90% of its transaction log alerts: a full log stalls every write."
  }

  assert {
    condition     = aws_iam_role_policy.events[0].name == "agrovesto-monitoring-events-policy"
    error_message = "The scheduler policy must exist for the metrics task."
  }
}

run "ecs_collector_is_scheduled" {
  command = plan

  assert {
    condition     = length(aws_ecs_task_definition.collector) == 1 && aws_ecs_task_definition.collector[0].family == "agrovesto-monitoring-ecs-collector"
    error_message = "The ECS collector task must exist."
  }

  assert {
    condition     = aws_ecs_task_definition.collector[0].network_mode == "awsvpc" && contains(aws_ecs_task_definition.collector[0].requires_compatibilities, "FARGATE")
    error_message = "The ECS collector must run as an awsvpc Fargate task."
  }

  assert {
    condition     = strcontains(local.collector_command, "ecs_metrics.py") && strcontains(local.collector_command, "ecs_logs.py")
    error_message = "The collector must run the ECS metrics script and the log shipper."
  }

  assert {
    condition     = strcontains(aws_s3_object.config["collector/ecs_metrics.py"].content, "ecs_cluster_running_tasks")
    error_message = "The ECS metrics script must be published for the collector."
  }

  assert {
    condition     = one(aws_efs_access_point.monitoring["collector"].root_directory).path == "/collector"
    error_message = "The collector needs its own access point so its checkpoint survives restarts."
  }

  assert {
    condition     = aws_cloudwatch_event_rule.collector[0].schedule_expression == "rate(2 minutes)" && aws_cloudwatch_event_target.collector[0].rule == aws_cloudwatch_event_rule.collector[0].name
    error_message = "The collector must be scheduled by EventBridge."
  }

  assert {
    condition     = strcontains(local.prometheus_ecs_rules, "EcsServiceShortOfTasks") && strcontains(local.prometheus_ecs_rules, "EcsLogShipperStalled")
    error_message = "The ECS rules must cover task shortfall and stalled log shipping."
  }
}

# -----------------------------------------------------------------------------
# The two extra collectors: basic CloudWatch metrics and the ALB access logs
# -----------------------------------------------------------------------------

run "cloudwatch_basic_metrics_are_collected" {
  command = plan

  assert {
    condition     = strcontains(local.collector_command, "cw_metrics.py")
    error_message = "The CloudWatch metric collector rides the existing ECS collector task: same schedule, same checkpoint volume, no second task to run."
  }

  assert {
    condition     = strcontains(aws_s3_object.config["collector/cw_metrics.py"].content, "cloudwatch_collector_up")
    error_message = "The collector script must be published for the init container to sync, and must report its own failure as a metric."
  }

  assert {
    condition = alltrue([
      strcontains(jsonencode(aws_ecs_task_definition.collector[0].container_definitions), "ALB_ARN_SUFFIX"),
      strcontains(jsonencode(aws_ecs_task_definition.collector[0].container_definitions), "METRIC_DELAY_SECONDS"),
      strcontains(jsonencode(aws_ecs_task_definition.collector[0].container_definitions), "SERVICE_PREFIX"),
    ])
    error_message = "The task hands the collector the prod load balancer, the CloudWatch delivery delay and the service name prefix."
  }

  assert {
    condition = alltrue([
      strcontains(jsonencode(aws_iam_role_policy.task.policy), "cloudwatch:GetMetricData"),
      strcontains(jsonencode(aws_iam_role_policy.task.policy), "cloudwatch:ListMetrics"),
    ])
    error_message = "Basic metrics need two CloudWatch actions; discovering dimensions with ListMetrics is what keeps every service describe permission out."
  }

  assert {
    condition = alltrue([
      strcontains(local.prometheus_cloudwatch_rules, "EcsServiceHighCpu"),
      strcontains(local.prometheus_cloudwatch_rules, "EcsServiceHighMemory"),
      strcontains(local.prometheus_cloudwatch_rules, "AlbUnhealthyTargets"),
      strcontains(local.prometheus_cloudwatch_rules, "AlbRejectingConnections"),
      strcontains(local.prometheus_cloudwatch_rules, "RdsLowDiskSpace"),
      strcontains(local.prometheus_cloudwatch_rules, "NatGatewayPortExhaustion"),
      strcontains(local.prometheus_cloudwatch_rules, "CloudwatchMetricsStale"),
    ])
    error_message = "Everything the collector publishes must be alertable: service CPU and memory, unhealthy targets, database resources, NAT ports, and the collector itself going quiet."
  }

  assert {
    condition = alltrue([
      aws_s3_object.config["grafana/dashboards/resources.json"].content_type == "application/json",
      strcontains(aws_s3_object.config["grafana/dashboards/resources.json"].content, "rds_free_storage_space_bytes"),
      strcontains(aws_s3_object.config["grafana/dashboards/resources.json"].content, "alb_unhealthy_hosts"),
      strcontains(aws_s3_object.config["grafana/dashboards/resources.json"].content, "nat_gateway_bytes_out_to_destination"),
    ])
    error_message = "The cloud resources dashboard is provisioned with the others and queries what the collector publishes."
  }

  assert {
    condition = alltrue([
      strcontains(aws_s3_object.config["grafana/dashboards/ecs.json"].content, "ecs_service_cpu_utilization_percent"),
      strcontains(aws_s3_object.config["grafana/dashboards/ecs.json"].content, "ecs_service_memory_utilization_percent"),
    ])
    error_message = "Per-service CPU and memory belong on the ECS platform dashboard, next to the task counts."
  }

  assert {
    condition     = output.dashboard_uids.resources == "agrovesto-resources"
    error_message = "The new dashboard uid is published with the others."
  }
}

run "alb_access_logs_are_shipped" {
  command = plan

  assert {
    condition     = strcontains(local.collector_command, "alb_logs.py")
    error_message = "The ALB access log shipper runs in the collector task too."
  }

  assert {
    condition     = startswith(local.alb_logs_bucket, "agrovesto-prod-alb-logs-")
    error_message = "With no explicit bucket the name prod/alb.tf creates is derived, so shipping works with no new variable value."
  }

  assert {
    condition = alltrue([
      strcontains(jsonencode(aws_ecs_task_definition.collector[0].container_definitions), "ALB_LOGS_BUCKET"),
      strcontains(jsonencode(aws_ecs_task_definition.collector[0].container_definitions), "ACCOUNT_ID"),
      strcontains(jsonencode(aws_ecs_task_definition.collector[0].container_definitions), "MAX_OBJECTS_PER_RUN"),
    ])
    error_message = "The task tells the shipper which bucket to read, whose account the key paths belong to and how much one run may take."
  }

  assert {
    condition = alltrue([
      strcontains(jsonencode(aws_iam_role_policy.task.policy), "s3:ListBucket"),
      strcontains(jsonencode(aws_iam_role_policy.task.policy), "arn:aws:s3:::${local.alb_logs_bucket}"),
      strcontains(jsonencode(aws_iam_role_policy.task.policy), "arn:aws:s3:::${local.alb_logs_bucket}/${var.alb_access_logs_prefix}*"),
    ])
    error_message = "The shipper reads the access log bucket and nothing else: list on the bucket, get on the prefix."
  }

  assert {
    condition = alltrue([
      strcontains(aws_s3_object.config["collector/alb_logs.py"].content, "alb_logs_shipper_up"),
      strcontains(aws_s3_object.config["collector/alb_logs.py"].content, "ELB-HealthChecker"),
    ])
    error_message = "The shipper reports its own state as a metric and keeps health checks distinguishable from client requests."
  }

  assert {
    condition = alltrue([
      strcontains(local.prometheus_alb_rules, "AlbLogShipperFailing"),
      strcontains(local.prometheus_alb_rules, "AlbLogShipperStalled"),
      strcontains(local.prometheus_alb_rules, "AlbAccessLogsMissing"),
      strcontains(local.prometheus_alb_rules, "AlbLogParseErrors"),
      strcontains(local.loki_rules, "AlbRequestErrorSpike"),
      strcontains(local.loki_rules, "AlbClientErrorFlood"),
    ])
    error_message = "A shipper that stops, a bucket that stops receiving and a log format that changes are all alertable, and the shipped lines drive the traffic alerts."
  }

  assert {
    condition = alltrue([
      aws_s3_object.config["grafana/dashboards/traffic.json"].content_type == "application/json",
      strcontains(aws_s3_object.config["grafana/dashboards/traffic.json"].content, "count_over_time"),
      strcontains(aws_s3_object.config["grafana/dashboards/traffic.json"].content, "client_ip"),
      strcontains(aws_s3_object.config["grafana/dashboards/traffic.json"].content, "user_agent"),
      strcontains(aws_s3_object.config["grafana/dashboards/traffic.json"].content, "alb_logs_shipped_total"),
    ])
    error_message = "The traffic dashboard counts requests per day per service and breaks them down by client IP, URI and user agent, and watches the shipper."
  }

  assert {
    condition     = output.dashboard_uids.traffic == "agrovesto-traffic"
    error_message = "The traffic dashboard uid is published with the others."
  }
}

run "loki_rules_are_published_under_the_tenant_directory" {
  command = plan

  # Loki's local rule storage reads <directory>/<tenant>/<namespace>, and with
  # auth_enabled false the tenant every line is ingested under is literally
  # "fake". A rule file one level higher is never loaded, and the ruler does not
  # complain: the alerts simply never evaluate.
  assert {
    condition     = contains(keys(aws_s3_object.config), "loki/rules/fake/application.yml")
    error_message = "The Loki rules must be published under the fake tenant directory or the ruler loads nothing."
  }

  assert {
    condition     = aws_s3_object.config["loki/rules/fake/application.yml"].key == "config/loki/rules/fake/application.yml"
    error_message = "The init container syncs config/loki into the task, so the rules land at /loki/config/rules/fake/application.yml."
  }

  assert {
    condition     = strcontains(local.loki_config, "directory: /loki/config/rules")
    error_message = "The ruler's local storage directory must be the directory the rules are synced into."
  }
}

run "extra_collectors_can_be_turned_off" {
  command = plan

  variables {
    enable_cloudwatch_metrics = false
    enable_alb_log_shipping   = false
  }

  assert {
    condition     = !strcontains(local.collector_command, "cw_metrics.py") && !strcontains(local.collector_command, "alb_logs.py")
    error_message = "Both extra collectors are optional."
  }

  assert {
    condition     = strcontains(local.collector_command, "ecs_metrics.py") && strcontains(local.collector_command, "ecs_logs.py")
    error_message = "Turning the extras off must not turn the ECS collector or its log shipper off."
  }

  assert {
    condition = alltrue([
      !contains(keys(aws_s3_object.config), "collector/cw_metrics.py"),
      !contains(keys(aws_s3_object.config), "collector/alb_logs.py"),
      !contains(keys(aws_s3_object.config), "prometheus/rules/cloudwatch.yml"),
      !contains(keys(aws_s3_object.config), "prometheus/rules/alb.yml"),
      !contains(keys(aws_s3_object.config), "grafana/dashboards/resources.json"),
      !contains(keys(aws_s3_object.config), "grafana/dashboards/traffic.json"),
    ])
    error_message = "Nothing that reads those metrics or logs is published when they are switched off."
  }

  assert {
    condition     = length(aws_s3_object.config) == 21
    error_message = "Back to what the ECS collector and its log shipper need."
  }

  assert {
    condition     = !strcontains(jsonencode(aws_iam_role_policy.task.policy), "cloudwatch:GetMetricData")
    error_message = "Without the CloudWatch collector the task role keeps no CloudWatch read."
  }

  assert {
    condition     = !strcontains(jsonencode(aws_iam_role_policy.task.policy), local.alb_logs_bucket)
    error_message = "Without the log shipper the task role keeps no access to the access log bucket."
  }

  assert {
    condition     = !contains(keys(output.dashboard_uids), "resources") && !contains(keys(output.dashboard_uids), "traffic")
    error_message = "The dashboard uids follow the collectors that fill them."
  }
}

run "scheduled_tasks_can_be_turned_off" {
  command = plan

  variables {
    enable_cost_monitoring = false
    enable_rds_monitoring  = false
  }

  assert {
    condition     = length(aws_s3_bucket.cur) == 0
    error_message = "No CUR bucket without a CUR report."
  }

  assert {
    condition     = length(aws_ecs_task_definition.budget) == 0 && length(aws_ecs_task_definition.mssql_metrics) == 0 && length(aws_ecs_task_definition.collector) == 1
    error_message = "The cost and database tasks must be gone while the ECS collector stays."
  }

  assert {
    condition     = length(aws_iam_role.events) == 1
    error_message = "The scheduler role is still needed by the ECS collector."
  }

  assert {
    condition     = length(aws_iam_role_policy.task_database_secret) == 0
    error_message = "Without RDS monitoring the database secret policy must go."
  }

  assert {
    condition = (
      length(aws_iam_role_policy.execution_database_secret) == 0 &&
      !strcontains(local.grafana_datasources, "type: mssql") &&
      !contains(keys(output.dashboard_uids), "database")
    )
    error_message = "Without RDS monitoring the Grafana MSSQL datasource, its execution-role secret policy and the Database dashboard all stay off."
  }

  assert {
    condition     = length(aws_s3_object.config) == 24
    error_message = "Without RDS monitoring the database script and rules are not published."
  }
}

run "monthly_report_is_mailed" {
  command = plan

  variables {
    report_recipients = ["finops@nomaos.com"]
  }

  assert {
    condition     = aws_ses_domain_identity.monthly_report[0].domain == "nomaos.com"
    error_message = "The report sender domain must be verified in SES."
  }

  assert {
    condition     = aws_ses_domain_dkim.monthly_report[0].domain == "nomaos.com"
    error_message = "DKIM must be generated for the verified domain."
  }

  assert {
    condition     = length(aws_route53_record.monthly_report_dkim) == 3 && aws_route53_record.monthly_report_dkim[0].type == "CNAME"
    error_message = "DKIM must be published for the verified domain."
  }

  assert {
    condition     = aws_route53_record.monthly_report_verification[0].type == "TXT"
    error_message = "The SES verification token must be published as a TXT record."
  }

  assert {
    condition     = aws_cloudwatch_event_rule.report[0].schedule_expression == var.report_schedule_expression
    error_message = "The monthly report must run on the configured schedule."
  }

  assert {
    condition     = strcontains(jsonencode(aws_ecs_task_definition.report[0].container_definitions), "fpdf2") && strcontains(jsonencode(aws_ecs_task_definition.report[0].container_definitions), "REPORT_RECIPIENTS")
    error_message = "The report task must render a PDF and know where to send it."
  }

  assert {
    condition     = strcontains(jsonencode(aws_ecs_task_definition.report[0].container_definitions), "finops@nomaos.com")
    error_message = "The report recipients must reach the task environment."
  }

  assert {
    condition     = aws_cloudwatch_event_target.report[0].ecs_target[0].launch_type == "FARGATE"
    error_message = "The report task must run on Fargate."
  }

  assert {
    condition     = aws_s3_object.report_script[0].key == "scripts/monthly_report.py"
    error_message = "The report script must be published next to the budget script."
  }
}

# The task policy embeds resource ARNs, so it is only known after apply - a plan
# run cannot evaluate it.
run "the_report_task_may_send_mail" {
  command = apply

  variables {
    report_recipients = ["finops@nomaos.com"]
  }

  assert {
    condition     = strcontains(jsonencode(aws_iam_role_policy.task.policy), "ses:SendRawEmail")
    error_message = "The report task must be allowed to send mail."
  }
}

run "rejects_team_mapping_outside_allowed_organizations" {
  command = plan

  variables {
    grafana_github_client_id     = "test-grafana-client-id"
    grafana_github_client_secret = "not-a-real-secret" # ggignore - test fixture
    grafana_github_team_roles = [
      { organization = "AnotherOrg", team_slug = "admins", role = "Admin" },
    ]
  }

  expect_failures = [aws_ecs_task_definition.grafana]
}

run "rejects_partial_grafana_github_credentials" {
  command = plan

  variables {
    grafana_github_client_id = "github-client-id-without-a-secret"
  }

  expect_failures = [aws_ecs_task_definition.grafana]
}
