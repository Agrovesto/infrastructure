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
    master_user_secret = [{
      secret_arn    = "arn:aws:secretsmanager:eu-west-1:221434544570:secret:rds!db-mock-AbCdEf"
      secret_status = "active"
      kms_key_id    = ""
    }]
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
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "GF_AUTH_GITHUB_ENABLED"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "GF_AUTH_GITHUB_CLIENT_SECRET"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "Agrovesto"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "user:email,read:org"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "https://grafana.nomaos.com"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "GF_AUTH_GITHUB_ROLE_ATTRIBUTE_PATH"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "@Agrovesto/infrastructure') && 'Admin'"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "@Agrovesto/team-leads') && 'Editor'"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "@Agrovesto/backend') && 'Viewer'"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "@Agrovesto/frontend') && 'Viewer'"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "@Agrovesto/mobile') && 'Viewer'"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "GF_AUTH_GITHUB_ROLE_ATTRIBUTE_STRICT"),
      strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "GITHUB_OAUTH_CONFIG_VERSION"),
      !strcontains(jsonencode(aws_ecs_task_definition.grafana.container_definitions), "not-a-real-secret"),
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
    condition     = strcontains(jsonencode(aws_ecs_task_definition.mssql_metrics[0].container_definitions), "pytds")
    error_message = "The metrics task must install the pure-Python TDS client."
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
    condition     = strcontains(aws_iam_role_policy.task_database_secret[0].policy, "secret:rds!db-mock-AbCdEf")
    error_message = "The secret policy must be scoped to the adopted instance's RDS-managed secret (data.aws_db_instance.mssql)."
  }

  assert {
    condition     = strcontains(jsonencode(aws_ecs_task_definition.mssql_metrics[0].container_definitions), "migration-prod.abc123.eu-west-1.rds.amazonaws.com")
    error_message = "DB_HOST must come from the RDS instance data source (managed secrets carry no host)."
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
    condition     = length(aws_s3_object.config) == 18
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
