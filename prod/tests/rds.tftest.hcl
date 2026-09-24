# =============================================================================
# PROD — RDS SQL Server, secrets, optional db-init bootstrap
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
  target = data.aws_region.current
  values = { name = "eu-west-1" }
}

override_data {
  target = data.aws_elb_service_account.main
  values = { id = "156460612806" }
}

variables {
  domain_name     = "nomaos.com"
  mssql_databases = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]
  mssql_multi_az  = false

  # This suite pins the NEW-instance design defaults. The adoption values from
  # terraform.auto.tfvars are covered by run "adopt_existing_instance".
  mssql_identifier                    = ""
  mssql_engine_version                = null
  mssql_allocated_storage_gb          = 20
  mssql_max_allocated_storage_gb      = 50
  mssql_storage_type                  = "gp3"
  mssql_storage_encrypted             = true
  mssql_performance_insights_enabled  = true
  mssql_master_username               = "agrovestoadmin"
  mssql_subnet_group_name             = ""
  mssql_additional_security_group_ids = []
  mssql_manage_master_user_password   = true
  mssql_existing_master_secret_arn    = ""
  mssql_monitoring_role_arn           = ""

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
# Instance
# -----------------------------------------------------------------------------

run "instance" {
  command = plan

  assert {
    condition     = aws_db_instance.mssql.identifier == "${var.project}-${var.environment}-mssql"
    error_message = "RDS identifier follows the naming convention."
  }

  assert {
    condition     = aws_db_instance.mssql.engine == var.mssql_engine
    error_message = "Engine must come from var.mssql_engine."
  }

  # Express: the licence is free, so the database costs the bare instance rate.
  # The limits being accepted are documented in terraform.auto.tfvars — the one
  # that bites is 10 GB per database.
  assert {
    condition     = aws_db_instance.mssql.engine == "sqlserver-ex"
    error_message = "Expected SQL Server Express (sqlserver-ex)."
  }

  assert {
    condition     = aws_db_instance.mssql.instance_class == var.mssql_instance_class
    error_message = "Instance class must come from var.mssql_instance_class."
  }

  # db.t3.micro (2 vCPU / 1 GiB) is the smallest instance SQL Server runs on at
  # all, and only Express/Web are offered on it.
  assert {
    condition     = aws_db_instance.mssql.instance_class == "db.t3.micro"
    error_message = "Expected db.t3.micro: the SQL Server hardware floor (2 vCPU / 1 GiB)."
  }

  assert {
    condition     = aws_db_instance.mssql.allocated_storage == 20
    error_message = "20 GiB is the documented minimum for SQL Server on gp3."
  }

  assert {
    condition     = aws_db_instance.mssql.max_allocated_storage == 50
    error_message = "Expected a 50 GB autoscaling ceiling."
  }

  assert {
    condition     = aws_db_instance.mssql.storage_type == "gp3"
    error_message = "Storage must be gp3."
  }

  assert {
    condition     = aws_db_instance.mssql.storage_encrypted == true
    error_message = "RDS storage must be encrypted at rest."
  }

  assert {
    condition     = aws_db_instance.mssql.publicly_accessible == false
    error_message = "The database must never be publicly accessible."
  }

  assert {
    condition     = aws_db_instance.mssql.port == 1433
    error_message = "SQL Server listens on 1433."
  }

  assert {
    condition     = aws_db_instance.mssql.username == var.mssql_master_username
    error_message = "Master username must come from var.mssql_master_username."
  }
}

# -----------------------------------------------------------------------------
# Availability + safety
# -----------------------------------------------------------------------------

run "availability_and_safety" {
  command = plan

  assert {
    condition     = aws_db_instance.mssql.multi_az == false
    error_message = "Multi-AZ is intentionally off for now (cost); flip var.mssql_multi_az at go-live."
  }

  assert {
    condition     = aws_db_instance.mssql.backup_retention_period == 30
    error_message = "Prod keeps 30 days of automated backups."
  }

  assert {
    condition     = aws_db_instance.mssql.deletion_protection == true
    error_message = "Deletion protection must stay on in prod."
  }

  assert {
    condition     = aws_db_instance.mssql.skip_final_snapshot == false
    error_message = "Prod must take a final snapshot on destroy."
  }

  assert {
    condition     = aws_db_instance.mssql.copy_tags_to_snapshot == true
    error_message = "Snapshots should inherit tags."
  }

  assert {
    condition     = aws_db_instance.mssql.auto_minor_version_upgrade == true
    error_message = "Auto minor version upgrades should stay on."
  }

  assert {
    condition     = aws_db_instance.mssql.apply_immediately == false
    error_message = "Changes should wait for the maintenance window, not apply immediately."
  }
}

run "multi_az_mode" {
  command = plan

  variables {
    mssql_multi_az = true
  }

  assert {
    condition     = aws_db_instance.mssql.multi_az == true
    error_message = "mssql_multi_az = true must enable the standby replica."
  }
}

# -----------------------------------------------------------------------------
# Monitoring + logs
# -----------------------------------------------------------------------------

run "monitoring" {
  command = plan

  assert {
    condition     = aws_db_instance.mssql.monitoring_interval == 60
    error_message = "Enhanced monitoring at 60s granularity (no extra charge)."
  }

  assert {
    condition     = aws_db_instance.mssql.performance_insights_enabled == true
    error_message = "Performance Insights should be enabled."
  }

  assert {
    condition     = aws_db_instance.mssql.performance_insights_retention_period == 7
    error_message = "7-day PI retention stays inside the free tier."
  }

  assert {
    condition     = toset(aws_db_instance.mssql.enabled_cloudwatch_logs_exports) == toset(["error"]) || toset(aws_db_instance.mssql.enabled_cloudwatch_logs_exports) == toset(["agent", "error"])
    error_message = "Agent + error logs must be exported to CloudWatch."
  }
}

# -----------------------------------------------------------------------------
# Credentials
# -----------------------------------------------------------------------------

run "credentials" {
  command = plan

  assert {
    condition     = aws_db_instance.mssql.manage_master_user_password == true
    error_message = "The master password must be RDS-managed so it never enters Terraform state."
  }

  assert {
    condition     = aws_db_instance.mssql.password == null
    error_message = "No master password may be set from Terraform."
  }

  assert {
    condition     = aws_db_instance.mssql.identifier == "${var.project}-${var.environment}-mssql"
    error_message = "Default identifier follows the <project>-<environment>-mssql convention."
  }
}

run "adopt_existing_instance" {
  command = plan

  # Mirrors the Adoption section of prod/terraform.auto.tfvars.
  variables {
    mssql_identifier                    = "migration-prod"
    mssql_engine_version                = "15.00.4445.1.v1"
    mssql_allocated_storage_gb          = 50
    mssql_max_allocated_storage_gb      = 63
    mssql_storage_type                  = "gp2"
    mssql_storage_encrypted             = false
    mssql_performance_insights_enabled  = true
    mssql_manage_master_user_password   = false
    mssql_existing_master_secret_arn    = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:agxdb2DBcredentials-26LKpW"
    mssql_monitoring_role_arn           = "arn:aws:iam::123456789012:role/rds-monitoring-role"
    mssql_master_username               = "agrovesto"
    mssql_subnet_group_name             = "agxdb2subnetgroup"
    mssql_additional_security_group_ids = ["sg-05a2722a050c1109b", "sg-0b555edfc6d445a18"]
  }

  assert {
    condition     = aws_db_instance.mssql.identifier == "migration-prod" && aws_db_instance.mssql.storage_type == "gp2" && aws_db_instance.mssql.allocated_storage == 50
    error_message = "The adoption variables must drive the adopted instance."
  }

  assert {
    condition     = aws_db_instance.mssql.storage_encrypted == false && aws_db_instance.mssql.performance_insights_enabled == true
    error_message = "Adopting migration-prod must not force a replacement and keeps Performance Insights as it is live."
  }

  assert {
    condition     = aws_db_subnet_group.mssql.name == "agxdb2subnetgroup" && aws_db_instance.mssql.manage_master_user_password == null
    error_message = "The adopted instance keeps its subnet group; its live password must not be rotated into an RDS-managed secret."
  }

  assert {
    condition     = aws_db_instance.mssql.monitoring_role_arn == "arn:aws:iam::123456789012:role/rds-monitoring-role" && length(aws_iam_role.rds_monitoring) == 0
    error_message = "The adopted instance reuses rds-monitoring-role instead of a duplicate role."
  }

  assert {
    condition     = length(aws_db_instance.mssql.vpc_security_group_ids) == 3
    error_message = "The design SG plus the two SGs migration-prod uses today."
  }
}

# -----------------------------------------------------------------------------
# Optional db-init task (off by default)
# -----------------------------------------------------------------------------

run "db_init_disabled_by_default" {
  command = plan

  assert {
    condition     = length(aws_ecs_task_definition.db_init) == 0
    error_message = "The db-init Fargate task must not exist while run_db_init = false."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.db_init) == 0
    error_message = "The db-init log group must not exist while run_db_init = false."
  }
}

run "db_init_enabled" {
  command = plan

  variables {
    run_db_init = true
  }

  assert {
    condition     = length(aws_ecs_task_definition.db_init) == 1
    error_message = "run_db_init = true must create the one-off init task."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.db_init) == 1
    error_message = "run_db_init = true must create the init task's log group."
  }

  # Deliberately x86: mcr.microsoft.com/mssql-tools ships amd64 only, so this
  # task must NOT inherit the ARM64 platform used by the services.
  assert {
    condition     = try(length(aws_ecs_task_definition.db_init[0].runtime_platform), 0) == 0
    error_message = "The db-init task must stay on the default x86_64 platform (mssql-tools is amd64-only)."
  }
}

# -----------------------------------------------------------------------------
# Step-up paths. Neither needs a rebuild: changing the instance class is a short
# reboot, changing the edition is a snapshot/restore migration.
# -----------------------------------------------------------------------------

run "step_up_to_small" {
  command = plan

  variables {
    mssql_instance_class = "db.t3.small"
  }

  assert {
    condition     = aws_db_instance.mssql.instance_class == "db.t3.small"
    error_message = "db.t3.small doubles RAM to 2 GiB for ~$13/mo — the first fix if db.t3.micro thrashes."
  }

  assert {
    condition     = aws_db_instance.mssql.engine == "sqlserver-ex"
    error_message = "Doubling RAM must not change the edition."
  }
}

run "standard_edition_step_up" {
  command = plan

  variables {
    mssql_engine                          = "sqlserver-se"
    mssql_instance_class                  = "db.m7i.large"
    mssql_enabled_cloudwatch_logs_exports = ["error", "agent"]
  }

  # Standard is not offered on db.t3.micro or db.t3.small: its burstable range
  # starts at db.t3.xlarge (4 vCPU), so 2 vCPU / 8 GiB is the floor.
  assert {
    condition     = aws_db_instance.mssql.instance_class == "db.m7i.large"
    error_message = "Standard's floor is db.m7i.large (2 vCPU / 8 GiB)."
  }

  assert {
    condition     = toset(aws_db_instance.mssql.enabled_cloudwatch_logs_exports) == toset(["error", "agent"])
    error_message = "Standard has SQL Server Agent, so the agent log can be published again."
  }
}

# -----------------------------------------------------------------------------
# The 10 GB guard: scheduled sqlcmd task -> log metric filter -> alarm
# -----------------------------------------------------------------------------

run "db_size_guard" {
  command = plan

  # prod/terraform.auto.tfvars turns the native guard off now that the
  # open-source stack watches the same metric, so pin it on for this run.
  variables {
    db_size_alarm_enabled = true
  }

  assert {
    condition     = length(aws_ecs_task_definition.db_size_check) == 1
    error_message = "The Express 10 GB guard must create its scheduled task definition."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.db_size_check) == 1
    error_message = "The size check needs its own log group for the metric filter to read."
  }

  assert {
    condition     = aws_cloudwatch_event_rule.db_size_check[0].schedule_expression == "rate(12 hours)"
    error_message = "The size check runs twice a day by default."
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.db_size_alert[0].pattern == "\"DB_SIZE_ALERT\""
    error_message = "The metric filter must match the DB_SIZE_ALERT token sqlcmd prints."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.db_size[0].threshold == 1
    error_message = "A single DB_SIZE_ALERT line is enough to alarm."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.db_size[0].period == 86400
    error_message = "A 24h period keeps the alarm steady instead of flapping between 12-hourly runs."
  }

  # mcr.microsoft.com/mssql-tools is amd64-only, so this task stays on x86.
  assert {
    condition     = try(length(aws_ecs_task_definition.db_size_check[0].runtime_platform), 0) == 0
    error_message = "The size-check task must stay on the default x86_64 platform (mssql-tools is amd64-only)."
  }
}

run "db_size_guard_with_email" {
  command = plan

  variables {
    db_size_alarm_email   = "ops@nomaos.com"
    db_size_alarm_enabled = true
  }

  assert {
    condition     = length(aws_sns_topic.db_size_alarm) == 1
    error_message = "Setting db_size_alarm_email must create an SNS topic."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.db_size[0].alarm_actions) == 1
    error_message = "With an email set, the alarm must notify the topic."
  }
}

run "db_size_guard_disabled" {
  command = plan

  variables {
    db_size_alarm_enabled = false
  }

  assert {
    condition = (
      length(aws_ecs_task_definition.db_size_check) == 0 &&
      length(aws_cloudwatch_log_group.db_size_check) == 0 &&
      length(aws_cloudwatch_metric_alarm.db_size) == 0 &&
      length(aws_cloudwatch_event_rule.db_size_check) == 0 &&
      length(aws_sns_topic.db_size_alarm) == 0
    )
    error_message = "db_size_alarm_enabled = false must remove the whole guard."
  }
}

# Express has no SQL Server Agent, so prod publishes only the error log. The
# variable default is error + agent because Standard needs the agent log; this
# run pins the production value.
run "express_log_exports" {
  command = plan

  variables {
    mssql_enabled_cloudwatch_logs_exports = ["error"]
  }

  assert {
    condition     = toset(aws_db_instance.mssql.enabled_cloudwatch_logs_exports) == toset(["error"])
    error_message = "On Express the only publishable SQL Server log is the error log."
  }
}
