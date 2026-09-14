# =============================================================================
# PROD — ECS Fargate cluster, task definitions, services, IAM, log groups
# =============================================================================

mock_provider "aws" {

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:loadbalancer/app/mock/1234567890123456"
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
    condition     = aws_iam_role.rds_monitoring.name == "${var.project}-${var.environment}-rds-monitoring-role"
    error_message = "RDS enhanced monitoring role keeps its convention name."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.rds_monitoring.policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
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
