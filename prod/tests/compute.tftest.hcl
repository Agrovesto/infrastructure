# =============================================================================
# PROD — ECS Fargate cluster, task definitions, services, IAM, log groups
# =============================================================================

mock_provider "aws" {

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:loadbalancer/app/mock/1234567890123456"
    }
  }

  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:listener/app/mock/1234567890123456/1234567890123456"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/mock-tg/1234567890123456"
    }
  }

  mock_resource "aws_ecs_cluster" {
    defaults = {
      arn = "arn:aws:ecs:eu-west-1:123456789012:cluster/mock-cluster"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:eu-west-1:123456789012:task-definition/mock-task:1"
    }
  }

  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:eu-west-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    }
  }

  mock_resource "aws_acm_certificate_validation" {
    defaults = {
      certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-west-1:123456789012:log-group:/aws/mock/log-group"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:eu-west-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    }
  }

  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      arn = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:mock-secret-123456"
    }
  }

  mock_resource "aws_secretsmanager_secret_version" {
    defaults = {
      arn = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:mock-secret-123456"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      arn      = "arn:aws:rds:eu-west-1:123456789012:db:mock-db"
      endpoint = "mock-db.123456789012.eu-west-1.rds.amazonaws.com:1433"
      address  = "mock-db.123456789012.eu-west-1.rds.amazonaws.com"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:eu-west-1:123456789012:mock-topic"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::mock-bucket"
    }
  }
}

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
  target = data.aws_region.current
  values = { name = "eu-west-1" }
}

override_data {
  target = data.aws_elb_service_account.main
  values = { id = "156460612806" }
}

variables {
  import_existing = false

  # Test the new-instance defaults, not the adoption values in terraform.auto.tfvars.
  mssql_monitoring_role_arn   = ""
  public_subnet_map_public_ip = false

  domain_name        = "nomaos.com"
  mssql_databases    = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]
  log_retention_days = 30

  services = {
    wallet = {
      image         = "ealen/echo-server:latest"
      port          = 5001
      cpu           = 256
      memory        = 512
      desired_count = 1
      subdomain     = "wallet-api"
    }
    onboarding = {
      image         = "ealen/echo-server:latest"
      port          = 5002
      cpu           = 256
      memory        = 512
      desired_count = 1
      subdomain     = "onboarding-api"
    }
    input = {
      image         = "ealen/echo-server:latest"
      port          = 5003
      cpu           = 256
      memory        = 512
      desired_count = 1
      subdomain     = "input-api"
    }
    moneval = {
      image         = "ealen/echo-server:latest"
      port          = 5004
      cpu           = 256
      memory        = 512
      desired_count = 1
      subdomain     = "moneval-api"
    }
    serviceprovider = {
      image         = "ealen/echo-server:latest"
      port          = 5005
      cpu           = 256
      memory        = 512
      desired_count = 1
      subdomain     = "serviceprovider-api"
    }
  }
}

# -----------------------------------------------------------------------------
# Cluster
# -----------------------------------------------------------------------------

run "cluster" {
  command = plan

  assert {
    condition     = aws_ecs_cluster.main.name == "${var.project}-${var.environment}"
    error_message = "Cluster name must follow the <project>-<environment> convention."
  }

  # setting is a TypeSet, so iterate instead of indexing.
  assert {
    condition     = [for s in aws_ecs_cluster.main.setting : s.name] == ["containerInsights"]
    error_message = "Container Insights setting must be present."
  }

  assert {
    condition     = [for s in aws_ecs_cluster.main.setting : s.value] == ["enabled"]
    error_message = "enable_container_insights = true should enable Container Insights."
  }
}

# -----------------------------------------------------------------------------
# Task definitions
# -----------------------------------------------------------------------------

run "task_definitions" {
  command = plan

  assert {
    condition     = length(aws_ecs_task_definition.services) == 5
    error_message = "One task definition per service."
  }

  assert {
    condition     = tonumber(aws_ecs_task_definition.services["wallet"].cpu) == 256
    error_message = "Task CPU must come from the service map (0.25 vCPU)."
  }

  assert {
    condition     = tonumber(aws_ecs_task_definition.services["wallet"].memory) == 512
    error_message = "Task memory must come from the service map."
  }

  assert {
    condition     = aws_ecs_task_definition.services["wallet"].network_mode == "awsvpc"
    error_message = "Fargate requires the awsvpc network mode."
  }

  assert {
    condition     = toset(aws_ecs_task_definition.services["wallet"].requires_compatibilities) == toset(["FARGATE"])
    error_message = "Tasks must be FARGATE compatible."
  }

  assert {
    condition     = aws_ecs_task_definition.services["wallet"].tags["Service"] == "wallet"
    error_message = "Task definitions carry a Service tag."
  }
}

# -----------------------------------------------------------------------------
# OpenTelemetry export
#
# The receiving side belongs to the monitoring stack (Alloy -> Tempo and
# Prometheus); these assertions cover the sending side, which is nothing but
# environment variables on the task definition. They are worth having because
# the failure mode is silent: an OTLP endpoint on the wrong port, or a service
# name that is not the service key, produces an empty Grafana rather than an
# error anywhere.
# -----------------------------------------------------------------------------

run "otel_environment" {
  command = plan

  locals {
    wallet_env = {
      for e in jsondecode(aws_ecs_task_definition.services["wallet"].container_definitions)[0].environment :
      e.name => e.value
    }
  }

  assert {
    condition     = local.wallet_env["OTEL_SERVICE_NAME"] == "wallet"
    error_message = "Each task names itself with its own service key, so a span is attributable to exactly one service."
  }

  assert {
    condition     = local.wallet_env["OTEL_EXPORTER_OTLP_ENDPOINT"] == var.otel.endpoint
    error_message = "Telemetry goes to the configured OTLP endpoint."
  }

  assert {
    condition     = local.wallet_env["OTEL_EXPORTER_OTLP_PROTOCOL"] == "grpc" && can(regex(":4317$", local.wallet_env["OTEL_EXPORTER_OTLP_ENDPOINT"]))
    error_message = "Protocol and port agree: gRPC is 4317, http/protobuf is 4318."
  }

  assert {
    condition = alltrue([
      for k, s in aws_ecs_task_definition.services : contains(
        [for e in jsondecode(s.container_definitions)[0].environment : e.name],
        "OTEL_SERVICE_NAME"
      )
    ])
    error_message = "Every service exports telemetry, not just the first one in the map."
  }

  assert {
    condition     = local.wallet_env["OTEL_LOGS_EXPORTER"] == "none"
    error_message = "Logs stay on the awslogs driver; exporting them over OTLP as well would store every line twice."
  }

  assert {
    condition = (
      strcontains(local.wallet_env["OTEL_RESOURCE_ATTRIBUTES"], "deployment.environment=prod") &&
      strcontains(local.wallet_env["OTEL_RESOURCE_ATTRIBUTES"], "service.namespace=agrovesto")
    )
    error_message = "Spans carry environment and namespace, so a trace cannot be mistaken for another stack's."
  }
}

run "otel_disabled" {
  command = plan

  variables {
    otel = { enabled = false }
  }

  assert {
    condition = !contains(
      [for e in jsondecode(aws_ecs_task_definition.services["wallet"].container_definitions)[0].environment : e.name],
      "OTEL_SERVICE_NAME"
    )
    error_message = "Turning telemetry off removes every OTEL_* variable instead of leaving a dead endpoint in the task."
  }
}

run "otel_per_service_override" {
  command = plan

  variables {
    otel = {
      enabled             = true
      resource_attributes = { "team" = "backend" }
    }
  }

  assert {
    condition     = strcontains(local.otel_resource_attributes, "team=backend")
    error_message = "Extra resource attributes are merged into the ones computed here."
  }

  assert {
    condition     = strcontains(local.otel_resource_attributes, "deployment.environment=prod")
    error_message = "Overriding one attribute cannot drop the computed identity attributes."
  }
}

# -----------------------------------------------------------------------------
# Services
# -----------------------------------------------------------------------------

run "services" {
  command = plan

  assert {
    condition     = length(aws_ecs_service.services) == 5
    error_message = "One ECS service per entry in var.services."
  }

  assert {
    condition     = aws_ecs_service.services["wallet"].launch_type == "FARGATE"
    error_message = "Services run on FARGATE."
  }

  assert {
    condition     = aws_ecs_service.services["wallet"].desired_count == 1
    error_message = "desired_count comes from the service map."
  }

  assert {
    condition     = one(aws_ecs_service.services["wallet"].network_configuration).assign_public_ip == false
    error_message = "Tasks live in private subnets with no public IP."
  }

  assert {
    condition     = [for lb in aws_ecs_service.services["wallet"].load_balancer : lb.container_port] == [5001]
    error_message = "The ALB must target the container port from the service map."
  }

  assert {
    condition     = one(aws_ecs_service.services["wallet"].deployment_circuit_breaker).enable == true
    error_message = "Prod services need the circuit breaker (auto-rollback on failed deploys)."
  }
}

run "services_single_az_pin" {
  command = plan

  variables {
    single_az_ecs = true
  }

  assert {
    condition     = length(one(aws_ecs_service.services["wallet"].network_configuration).subnets) == 1
    error_message = "single_az_ecs = true pins every task to the first private subnet."
  }
}

# -----------------------------------------------------------------------------
# Log groups
# -----------------------------------------------------------------------------

run "log_groups" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_group.services) == 5
    error_message = "One log group per service."
  }

  assert {
    condition     = aws_cloudwatch_log_group.services["wallet"].name == "/ecs/${var.project}-${var.environment}/wallet"
    error_message = "Log group naming must follow /ecs/<project>-<env>/<service>."
  }

  assert {
    condition     = aws_cloudwatch_log_group.services["wallet"].retention_in_days == 30
    error_message = "Service log retention must follow var.log_retention_days (30)."
  }
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------

run "iam" {
  command = plan

  assert {
    condition     = aws_iam_role.ecs_execution.name == "${var.project}-${var.environment}-ecs-execution-role"
    error_message = "Execution role keeps the <project>-<environment>-ecs-execution-role name."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.ecs_execution.policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    error_message = "The execution role needs the ECS task execution managed policy."
  }

  assert {
    condition     = aws_iam_role.ecs_task.name == "${var.project}-${var.environment}-ecs-task-role"
    error_message = "Task role keeps its convention name."
  }

  assert {
    condition     = aws_iam_role.rds_monitoring[0].name == "${var.project}-${var.environment}-rds-monitoring-role"
    error_message = "RDS enhanced monitoring role keeps its convention name."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.rds_monitoring[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
    error_message = "The monitoring role needs the RDS enhanced monitoring managed policy."
  }
}

# -----------------------------------------------------------------------------
# Rendered container definitions (apply, so the secret ARNs are resolved)
# -----------------------------------------------------------------------------

run "container_definitions" {
  command = apply

  assert {
    condition     = length(jsondecode(aws_ecs_task_definition.services["wallet"].container_definitions)) == 1
    error_message = "Exactly one container per task definition."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.services["wallet"].container_definitions)[0].name == "wallet"
    error_message = "Container name is the service key (the ALB targets it by name)."
  }

  assert {
    condition     = tonumber(jsondecode(aws_ecs_task_definition.services["wallet"].container_definitions)[0].portMappings[0].containerPort) == 5001
    error_message = "Container port must match the service map."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.services["wallet"].container_definitions)[0].logConfiguration.logDriver == "awslogs"
    error_message = "Containers must log to CloudWatch via awslogs."
  }

  assert {
    condition     = contains([for e in jsondecode(aws_ecs_task_definition.services["wallet"].container_definitions)[0].environment : e.value if try(e.name, "") == "DB_NAME"], "wallet")
    error_message = "DB_NAME must equal the service key (service name == database name, as in dev)."
  }

  assert {
    condition     = contains([for e in jsondecode(aws_ecs_task_definition.services["wallet"].container_definitions)[0].environment : e.value if try(e.name, "") == "VAULT_ADDR"], "https://vault.nomaos.com")
    error_message = "Services must receive VAULT_ADDR while Vault is enabled."
  }

  assert {
    condition     = contains([for s in try(jsondecode(aws_ecs_task_definition.services["wallet"].container_definitions)[0].secrets, []) : s.name], "DB_PASSWORD")
    error_message = "Bootstrap mode (vault_secrets_enabled = false) injects DB_PASSWORD from Secrets Manager."
  }
}

run "container_definitions_with_vault_secrets" {
  command = apply

  variables {
    vault_secrets_enabled = true
  }

  assert {
    condition     = length(jsondecode(aws_ecs_task_definition.services["wallet"].container_definitions)[0].secrets) == 0
    error_message = "vault_secrets_enabled = true must stop injecting DB creds from Secrets Manager."
  }
}

# -----------------------------------------------------------------------------
# Autoscaling — one warm task per service, scale out on load
# -----------------------------------------------------------------------------

run "autoscaling" {
  command = plan

  assert {
    condition     = length(aws_appautoscaling_target.services) == 5
    error_message = "One autoscaling target per service."
  }

  assert {
    condition     = contains(keys(aws_appautoscaling_target.services), "vault") == false
    error_message = "Vault must never autoscale: raft on EFS needs exactly one writer."
  }

  assert {
    condition     = aws_appautoscaling_target.services["wallet"].min_capacity == 1
    error_message = "min_capacity = 1 keeps a warm task: at 0 the ALB has no healthy target and 503s."
  }

  assert {
    condition     = aws_appautoscaling_target.services["wallet"].max_capacity == var.ecs_autoscaling_max_capacity
    error_message = "max_capacity must come from var.ecs_autoscaling_max_capacity."
  }

  assert {
    condition     = aws_appautoscaling_target.services["wallet"].service_namespace == "ecs"
    error_message = "Targets belong to the ecs namespace."
  }

  assert {
    condition     = aws_appautoscaling_target.services["wallet"].scalable_dimension == "ecs:service:DesiredCount"
    error_message = "ECS autoscaling scales DesiredCount."
  }

  assert {
    condition     = length(aws_appautoscaling_policy.services) == 5
    error_message = "One scaling policy per service."
  }

  assert {
    condition     = aws_appautoscaling_policy.services["wallet"].policy_type == "TargetTrackingScaling"
    error_message = "Policies are target-tracking (no manual step adjustments to tune)."
  }

  assert {
    condition = flatten([
      for c in aws_appautoscaling_policy.services["wallet"].target_tracking_scaling_policy_configuration : [
        for m in c.predefined_metric_specification : m.predefined_metric_type
      ]
    ]) == ["ALBRequestCountPerTarget"]
    error_message = "Scale on ALB requests per target, not raw CPU."
  }

  assert {
    condition = [
      for c in aws_appautoscaling_policy.services["wallet"].target_tracking_scaling_policy_configuration : c.target_value
    ] == [1000]
    error_message = "Target 1000 requests/minute/task (~16 rps)."
  }

  assert {
    condition = [
      for c in aws_appautoscaling_policy.services["wallet"].target_tracking_scaling_policy_configuration : c.scale_out_cooldown
    ] == [60]
    error_message = "Scale out quickly (60s) so load spikes are absorbed."
  }
}

run "autoscaling_disabled" {
  command = plan

  variables {
    ecs_autoscaling_enabled = false
  }

  assert {
    condition     = length(aws_appautoscaling_target.services) == 0
    error_message = "ecs_autoscaling_enabled = false must create no scaling targets."
  }

  assert {
    condition     = length(aws_appautoscaling_policy.services) == 0
    error_message = "ecs_autoscaling_enabled = false must create no scaling policies."
  }
}

# -----------------------------------------------------------------------------
# Graviton (ARM64) + the smallest Fargate task size
# -----------------------------------------------------------------------------

run "graviton_tasks" {
  command = plan

  assert {
    condition     = [for p in aws_ecs_task_definition.services["wallet"].runtime_platform : p.cpu_architecture] == ["ARM64"]
    error_message = "Service tasks run on Graviton (ARM64): ~20% cheaper than x86. Images must be built for linux/arm64."
  }

  assert {
    condition     = [for p in aws_ecs_task_definition.services["wallet"].runtime_platform : p.operating_system_family] == ["LINUX"]
    error_message = "Operating system family is LINUX."
  }

  assert {
    condition = (
      tonumber(aws_ecs_task_definition.services["wallet"].cpu) == 256 &&
      tonumber(aws_ecs_task_definition.services["wallet"].memory) == 512
    )
    error_message = "256 CPU / 512 MB is the smallest Fargate task that exists."
  }

  assert {
    condition = alltrue([
      for k, t in aws_ecs_task_definition.services : length([
        for p in t.runtime_platform : p.cpu_architecture if p.cpu_architecture == "ARM64"
      ]) == 1
    ])
    error_message = "Every service task, not just wallet, must be on ARM64."
  }
}

run "x86_fallback" {
  command = plan

  variables {
    ecs_cpu_architecture = "X86_64"
  }

  assert {
    condition     = [for p in aws_ecs_task_definition.services["wallet"].runtime_platform : p.cpu_architecture] == ["X86_64"]
    error_message = "ecs_cpu_architecture = X86_64 must put tasks back on x86 (escape hatch for amd64-only images)."
  }
}

# -----------------------------------------------------------------------------
# SNS topics + baseline alarms (sns.tf, alarms.tf)
# -----------------------------------------------------------------------------

run "sns_and_alarms" {
  command = plan

  variables {
    alert_emails     = ["ops@example.com"]
    app_sns_topics   = ["notifications", "orders"]
    app_topic_emails = ["dev@example.com"]
  }

  assert {
    condition     = aws_kms_key.sns.enable_key_rotation && aws_kms_alias.sns.name == "alias/${var.project}-${var.environment}-sns"
    error_message = "SNS topics use a rotating customer-managed key (alarms cannot publish to aws/sns)."
  }

  assert {
    condition     = aws_sns_topic.alerts.name == "${var.project}-${var.environment}-alerts"
    error_message = "Alerts topic follows the naming convention."
  }

  assert {
    condition     = aws_sns_topic_policy.alerts != null
    error_message = "The alerts topic has a policy letting CloudWatch publish."
  }

  assert {
    condition     = length(aws_sns_topic_subscription.alerts_email) == 1 && aws_sns_topic_subscription.alerts_email["ops@example.com"].protocol == "email"
    error_message = "Every alert email gets an email subscription."
  }

  assert {
    condition     = length(aws_sns_topic.app) == 2 && length(aws_sns_topic_subscription.app_email) == 2
    error_message = "One topic per app_sns_topics entry, each subscribed by every app_topic_emails address."
  }

  assert {
    condition     = length(aws_iam_role_policy.ecs_task_sns) == 1
    error_message = "The ECS task role may publish to the app topics."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.rds_cpu.namespace == "AWS/RDS" && aws_cloudwatch_metric_alarm.rds_storage.threshold == 5 * 1024 * 1024 * 1024 && aws_cloudwatch_metric_alarm.rds_memory.metric_name == "FreeableMemory"
    error_message = "RDS CPU, free storage (5 GB) and memory alarms exist."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.alb_5xx.metric_name == "HTTPCode_ELB_5XX_Count"
    error_message = "ALB 5xx alarm exists."
  }

  assert {
    condition = alltrue([
      length(aws_cloudwatch_metric_alarm.target_5xx) == length(var.services),
      length(aws_cloudwatch_metric_alarm.unhealthy_targets) == length(var.services),
      length(aws_cloudwatch_metric_alarm.ecs_cpu) == length(var.services),
      length(aws_cloudwatch_metric_alarm.ecs_memory) == length(var.services),
    ])
    error_message = "Every service gets 5xx, unhealthy-target, CPU and memory alarms."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ecs_cpu["wallet"].threshold == 85 && aws_cloudwatch_metric_alarm.unhealthy_targets["wallet"].comparison_operator == "GreaterThanThreshold"
    error_message = "ECS alarms use the default 85% threshold; any unhealthy target alarms."
  }
}

# -----------------------------------------------------------------------------
# IAM policy documents, network edges and optional features. apply (mocked) so
# the documents that depend on ARNs are resolved.
# -----------------------------------------------------------------------------

run "iam_documents_and_wiring" {
  command = apply

  variables {
    db_size_alarm_enabled         = true
    db_size_alarm_email           = "ops@example.com"
    manage_default_security_group = true
  }

  # --- ECS execution ---------------------------------------------------------
  assert {
    condition     = one(one(data.aws_iam_policy_document.ecs_execution_assume.statement).principals).identifiers == toset(["ecs-tasks.amazonaws.com"])
    error_message = "Only ECS tasks may assume the execution/task roles."
  }

  assert {
    condition     = [for s in data.aws_iam_policy_document.ecs_execution_secrets.statement : s.sid] == ["ReadMssqlMasterSecret", "DecryptMssqlMasterSecret"]
    error_message = "Execution role reads only the master secret and decrypts it."
  }

  assert {
    condition     = toset(one(data.aws_iam_policy_document.ecs_execution_secrets.statement[1].condition).values) == toset(["secretsmanager.eu-west-1.amazonaws.com"])
    error_message = "kms:Decrypt is limited to Secrets Manager (kms:ViaService)."
  }

  assert {
    condition     = aws_iam_role_policy.ecs_execution_secrets.name == "${var.project}-${var.environment}-ecs-execution-secrets"
    error_message = "The secrets policy is attached to the execution role."
  }

  assert {
    condition     = one(one(data.aws_iam_policy_document.rds_monitoring_assume.statement).principals).identifiers == toset(["monitoring.rds.amazonaws.com"])
    error_message = "Only RDS enhanced monitoring may assume the monitoring role."
  }

  # --- Flow logs ---------------------------------------------------------------
  assert {
    condition     = one(one(data.aws_iam_policy_document.flow_logs_assume.statement).principals).identifiers == toset(["vpc-flow-logs.amazonaws.com"])
    error_message = "Only VPC flow logs may assume the flow-logs role."
  }

  assert {
    condition     = contains(one(data.aws_iam_policy_document.flow_logs.statement).actions, "logs:PutLogEvents") && length(one(data.aws_iam_policy_document.flow_logs.statement).resources) == 2
    error_message = "Flow logs may write only to their own log group (and its streams)."
  }

  assert {
    condition     = aws_iam_role.flow_logs.name == "${var.project}-${var.environment}-flow-logs-role" && aws_iam_role_policy.flow_logs.name == "${var.project}-${var.environment}-flow-logs-policy"
    error_message = "Flow-logs role and policy keep their convention names."
  }

  # --- ALB access logs -----------------------------------------------------------
  assert {
    condition     = [for s in data.aws_iam_policy_document.alb_logs.statement : s.sid] == ["AllowELBLogDelivery", "AllowELBServiceAccount"]
    error_message = "ALB log bucket allows both the log-delivery principal and the regional ELB account."
  }

  assert {
    condition     = one(data.aws_iam_policy_document.alb_logs.statement[1].principals).identifiers == toset(["arn:aws:iam::156460612806:root"])
    error_message = "The legacy statement names the regional ELB account."
  }

  assert {
    condition     = aws_s3_bucket_policy.alb_logs.bucket == aws_s3_bucket.alb_logs.id
    error_message = "The log-delivery policy is on the ALB logs bucket."
  }

  # --- DB size check (db_size_alarm_enabled) --------------------------------------
  assert {
    condition     = one(one(data.aws_iam_policy_document.events_assume[0].statement).principals).identifiers == toset(["events.amazonaws.com"])
    error_message = "Only EventBridge may assume the events role."
  }

  assert {
    condition     = [for s in data.aws_iam_policy_document.events_run_task[0].statement : s.sid] == ["RunDatabaseSizeCheck", "PassTaskRoles"]
    error_message = "EventBridge may only run the size-check task and pass its two roles."
  }

  assert {
    condition     = aws_iam_role.events[0].name == "${var.project}-${var.environment}-events-role" && aws_iam_role_policy.events_run_task[0].name == "${var.project}-${var.environment}-events-run-task"
    error_message = "Events role and policy keep their convention names."
  }

  assert {
    condition = alltrue([
      one(aws_cloudwatch_event_target.db_size_check[0].ecs_target).launch_type == "FARGATE",
      one(one(aws_cloudwatch_event_target.db_size_check[0].ecs_target).network_configuration).assign_public_ip == false,
    ])
    error_message = "The size check runs on Fargate in a private subnet without a public IP."
  }

  assert {
    condition     = aws_sns_topic_subscription.db_size_alarm[0].endpoint == "ops@example.com" && aws_sns_topic_subscription.db_size_alarm[0].protocol == "email"
    error_message = "db_size_alarm_email is subscribed to the size alarm topic."
  }

  # --- Vault -----------------------------------------------------------------------
  assert {
    condition     = one(one(data.aws_iam_policy_document.vault_kms.statement).principals).identifiers == toset(["arn:aws:iam::123456789012:root"])
    error_message = "The Vault key policy delegates to the account root only."
  }

  assert {
    condition     = one(data.aws_iam_policy_document.vault_task.statement).actions == toset(["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"])
    error_message = "Vault gets only the KMS actions auto-unseal needs."
  }

  assert {
    condition     = aws_iam_role.vault_task[0].name == "${var.project}-${var.environment}-vault-task-role" && aws_iam_role_policy.vault_task[0].name == "${var.project}-${var.environment}-vault-task-policy"
    error_message = "Vault task role and policy keep their convention names."
  }

  # --- ACM + network edges -------------------------------------------------------------
  assert {
    condition     = aws_acm_certificate_validation.wildcard.certificate_arn == aws_acm_certificate.wildcard.arn
    error_message = "The HTTPS listener waits for the wildcard certificate to validate."
  }

  assert {
    condition     = length(aws_default_security_group.default) == 1 && aws_default_security_group.default[0].tags["Name"] == "${var.project}-${var.environment}-default-sg"
    error_message = "manage_default_security_group = true takes over (and empties) the default SG."
  }

  assert {
    condition     = aws_internet_gateway.main.tags["Name"] == "${var.project}-${var.environment}-igw" && aws_route_table.public.tags["Name"] == "${var.project}-${var.environment}-public-rt"
    error_message = "IGW and public route table keep their convention names."
  }

  assert {
    condition     = length(aws_route_table_association.public) == 2 && alltrue([for a in aws_route_table_association.public : a.route_table_id == aws_route_table.public.id])
    error_message = "Both public subnets use the shared public route table."
  }

  assert {
    condition     = [for rt in aws_route_table.private : rt.tags["Name"]] == ["${var.project}-${var.environment}-private-rt-1", "${var.project}-${var.environment}-private-rt-2"]
    error_message = "One private route table per private subnet."
  }
}

run "db_init_bootstrap" {
  command = plan

  variables {
    run_db_init = true
  }

  assert {
    condition     = null_resource.db_init[0].triggers.sql == join(" ", [for db in var.mssql_databases : "IF DB_ID(N'${db}') IS NULL CREATE DATABASE [${db}];"])
    error_message = "db-init re-runs when the database list changes and only creates missing databases."
  }
}

# --- Rekognition --------------------------------------------------------------
run "rekognition" {
  command = apply

  assert {
    condition     = aws_s3_bucket_versioning.rekognition.versioning_configuration[0].status == "Enabled"
    error_message = "The media bucket is versioned (old versions expire after 7 days)."
  }
  assert {
    condition     = [for c in aws_rekognition_collection.this : c.collection_id] == ["${local.name}-customers"]
    error_message = "One KYC face collection by default, named after the stack."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.rekognition.block_public_acls &&
      aws_s3_bucket_public_access_block.rekognition.restrict_public_buckets &&
      aws_s3_bucket_ownership_controls.rekognition.rule[0].object_ownership == "BucketOwnerEnforced" &&
      one(aws_s3_bucket_server_side_encryption_configuration.rekognition.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    )
    error_message = "The media bucket is private and encrypted."
  }

  assert {
    condition     = startswith(aws_s3_bucket.rekognition.bucket, "${local.name}-rekognition-") && strcontains(aws_s3_bucket_policy.rekognition.policy, "aws:SecureTransport")
    error_message = "The media bucket is account-scoped and TLS-only."
  }

  assert {
    condition = contains([
      for r in aws_s3_bucket_lifecycle_configuration.rekognition.rule : r.expiration[0].days if r.id == "expire-liveness-audit-images"
    ], 30)
    error_message = "Liveness audit images expire after 30 days by default."
  }

  assert {
    condition = (
      aws_sns_topic.rekognition_video.name == "${local.name}-rekognition-video" &&
      aws_sns_topic_subscription.rekognition_video.protocol == "sqs" &&
      aws_sns_topic_subscription.rekognition_video.raw_message_delivery &&
      aws_sqs_queue.rekognition_video.sqs_managed_sse_enabled &&
      aws_sqs_queue.rekognition_video_dlq.message_retention_seconds == 1209600 &&
      aws_sqs_queue_policy.rekognition_video.queue_url != null
    )
    error_message = "Video job status flows SNS -> encrypted SQS with a DLQ."
  }

  assert {
    condition     = strcontains(aws_iam_role.rekognition_video.assume_role_policy, "rekognition.amazonaws.com") && aws_iam_role_policy.rekognition_video.name == "publish-job-status"
    error_message = "Rekognition publishes video job status through its own role."
  }

  assert {
    condition = (
      length(aws_cognito_identity_pool.liveness) == 1 &&
      aws_cognito_identity_pool.liveness[0].allow_unauthenticated_identities &&
      !aws_cognito_identity_pool.liveness[0].allow_classic_flow &&
      length(aws_cognito_identity_pool_roles_attachment.liveness) == 1 &&
      strcontains(aws_iam_role_policy.liveness_guest[0].policy, "rekognition:StartFaceLivenessSession") &&
      !strcontains(aws_iam_role_policy.liveness_guest[0].policy, "Detect") &&
      aws_iam_role.liveness_guest[0].name == "${local.name}-rekognition-liveness-guest"
    )
    error_message = "Liveness guests can only stream a liveness session."
  }

  assert {
    condition     = aws_iam_role_policy.app_rekognition.name == "${local.name}-app-rekognition"
    error_message = "The application role gets the Rekognition policy."
  }
}

run "rekognition_minimal" {
  command = plan

  variables {
    rekognition = { collections = [], liveness_identity_pool = false }
  }

  assert {
    condition     = length(aws_rekognition_collection.this) == 0 && length(aws_cognito_identity_pool.liveness) == 0 && length(aws_iam_role.liveness_guest) == 0
    error_message = "Collections and the liveness guest pool are optional."
  }
}
