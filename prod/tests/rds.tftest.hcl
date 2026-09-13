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
    condition     = aws_db_instance.mssql.engine == "sqlserver-se"
    error_message = "Engine must be SQL Server Standard (sqlserver-se)."
  }

  assert {
    condition     = aws_db_instance.mssql.instance_class == var.mssql_instance_class
    error_message = "Instance class must come from var.mssql_instance_class."
  }

  # Standard Edition is not offered on db.t3.medium/large (burstable starts at
  # db.t3.xlarge = 4 vCPU), and the License-Included fee is per vCPU — so the
  # cheapest Standard is a 2 vCPU class on the "unbundled" 7th-gen list.
  assert {
    condition     = aws_db_instance.mssql.instance_class == "db.m7i.large"
    error_message = "Expected db.m7i.large: 2 vCPU halves the SQL Server licence vs db.t3.xlarge (4 vCPU)."
  }

  assert {
    condition     = aws_db_instance.mssql.allocated_storage == 20
    error_message = "20 GiB is the documented minimum for SQL Server Standard on gp3."
  }

  assert {
    condition     = aws_db_instance.mssql.max_allocated_storage == 100
    error_message = "Expected a 100 GB autoscaling ceiling."
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
    condition     = sort(tolist(aws_db_instance.mssql.enabled_cloudwatch_logs_exports)) == ["agent", "error"]
    error_message = "Agent + error logs must be exported to CloudWatch."
  }
}

# -----------------------------------------------------------------------------
# Credentials
# -----------------------------------------------------------------------------

run "credentials" {
  command = plan

  assert {
    condition     = aws_secretsmanager_secret.mssql_master.name == "${var.project}-${var.environment}-mssql-master"
    error_message = "Master credentials live in a conventionally named secret."
  }

  assert {
    condition     = aws_secretsmanager_secret.mssql_master.recovery_window_in_days == 7
    error_message = "Keep a 7-day recovery window on the prod secret."
  }

  assert {
    condition     = random_password.mssql_master.length == 32
    error_message = "The generated master password is 32 characters."
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
    condition     = length([for p in aws_ecs_task_definition.db_init[0].runtime_platform : p.cpu_architecture]) == 0
    error_message = "The db-init task must stay on the default x86_64 platform (mssql-tools is amd64-only)."
  }
}
