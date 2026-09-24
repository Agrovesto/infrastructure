# =============================================================================
# RDS SQL Server — one Multi-AZ instance hosting the same 5 databases as dev
# (wallet, onboarding, input, moneval, serviceprovider).
#
# Credentials: RDS-managed master password (Secrets Manager secret owned by RDS,
# never in Terraform state or GitHub secrets), injected into the ECS tasks as
# DB_USER / DB_PASSWORD.
#
# Databases: RDS cannot create databases via the aws_db_instance resource, so
# when var.run_db_init = true a one-off Fargate task runs `CREATE DATABASE`
# for every name in var.mssql_databases (triggered from the CI runner through
# the AWS API — the runner itself needs no VPC access). Runbook SQL is also
# printed in the `mssql_db_init_sql` output for manual use.
# =============================================================================

# Master password: RDS-managed (manage_master_user_password). RDS generates it,
# stores it in its own Secrets Manager secret ("rds!db-...") and rotates it.
# The value never passes through Terraform, so it is not in plan output or in
# state - consumers read it at runtime via aws_db_instance.mssql
# .master_user_secret[0].secret_arn (keys: username, password).
#
# Adopting the existing instance (imports/RUNBOOK.md): migration-prod does NOT
# use a managed secret (the import plan showed manage_master_user_password
# null -> true, which would ROTATE the live password and break every current
# client). So for the adopted instance var.mssql_manage_master_user_password =
# false: Terraform never sets or reads the password, and consumers use the
# existing Secrets Manager secret in var.mssql_existing_master_secret_arn.

locals {
  mssql_identifier        = var.mssql_identifier != "" ? var.mssql_identifier : "${local.name}-mssql"
  mssql_master_secret_arn = var.mssql_existing_master_secret_arn != "" ? var.mssql_existing_master_secret_arn : try(aws_db_instance.mssql.master_user_secret[0].secret_arn, "")
}

resource "aws_db_instance" "mssql" {
  identifier = local.mssql_identifier

  engine               = var.mssql_engine
  engine_version       = var.mssql_engine_version
  instance_class       = var.mssql_instance_class
  parameter_group_name = null # default parameter group; add a custom one when needed

  allocated_storage     = var.mssql_allocated_storage_gb
  max_allocated_storage = var.mssql_max_allocated_storage_gb
  storage_type          = var.mssql_storage_type
  # ForceNew. true for every new instance; false ONLY while the adopted,
  # unencrypted migration-prod is in service (encrypt-by-restore: RUNBOOK §4.2).
  #trivy:ignore:AVD-AWS-0080
  storage_encrypted = var.mssql_storage_encrypted

  db_subnet_group_name = aws_db_subnet_group.mssql.name
  # The design's RDS SG plus any SGs the adopted instance still relies on
  # (legacy EC2 -> DB paths), so adoption does not cut existing connections.
  vpc_security_group_ids = concat([aws_security_group.rds.id], var.mssql_additional_security_group_ids)
  publicly_accessible    = false
  port                   = var.mssql_port

  username                    = var.mssql_master_username
  manage_master_user_password = var.mssql_manage_master_user_password ? true : null

  multi_az = var.mssql_multi_az

  backup_retention_period = var.mssql_backup_retention_days
  backup_window           = var.mssql_backup_window      # UTC
  maintenance_window      = var.mssql_maintenance_window # UTC, outside the backup window
  copy_tags_to_snapshot   = true

  skip_final_snapshot       = var.mssql_skip_final_snapshot
  final_snapshot_identifier = var.mssql_skip_final_snapshot ? null : "${local.mssql_identifier}-final-snapshot"
  deletion_protection       = var.deletion_protection

  # Enhanced monitoring + log exports to CloudWatch + Performance Insights
  # (free 7-day retention tier). The log types are a variable because Express
  # has no SQL Server Agent, so there is no agent log to publish.
  monitoring_interval             = 60
  monitoring_role_arn             = local.rds_monitoring_role_arn
  enabled_cloudwatch_logs_exports = var.mssql_enabled_cloudwatch_logs_exports
  # SQL Server Express does not support Performance Insights.
  performance_insights_enabled          = var.mssql_performance_insights_enabled
  performance_insights_retention_period = var.mssql_performance_insights_enabled ? 7 : null

  auto_minor_version_upgrade = true
  apply_immediately          = false

  tags = merge(local.tags, { Name = local.mssql_identifier })

  lifecycle {
    # Password is never managed here (RDS-managed secret, or the adopted
    # instance's existing secret).
    ignore_changes = [password]
  }
}

# -----------------------------------------------------------------------------
# Optional database bootstrap (var.run_db_init = true)
#
# A tiny Fargate task running the mssql-tools image creates every database in
# var.mssql_databases. The Terraform provisioner drives it entirely through the
# AWS API, so the CI runner never needs a network path into the VPC.
# -----------------------------------------------------------------------------

# CloudWatch default encryption is enough here too - mirrors checkov CKV_AWS_158 skip.
#trivy:ignore:AVD-AWS-0017
resource "aws_cloudwatch_log_group" "db_init" {
  count = var.run_db_init ? 1 : 0

  name              = "/ecs/${local.name}/db-init"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

# mssql-tools image is fine for a one-off bootstrap container - mirrors checkov CKV_AWS_333 style rules.
resource "aws_ecs_task_definition" "db_init" {
  count = var.run_db_init ? 1 : 0

  family                   = "${local.name}-db-init"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  # Deliberately NOT Graviton: mcr.microsoft.com/mssql-tools ships amd64 only,
  # so this task stays on the default x86_64 platform. One one-off task, so
  # there is nothing to save by porting it.
  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "db-init"
      image     = "mcr.microsoft.com/mssql-tools:latest"
      essential = true

      command = [
        "sh", "-c",
        "set -e; for db in $DB_LIST; do echo \"creating database $db (if missing)\"; sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P \"$DB_PASSWORD\" -l 30 -Q \"IF DB_ID(N'$db') IS NULL CREATE DATABASE [$db];\"; done; echo 'all databases present'"
      ]

      environment = [
        { name = "DB_HOST", value = split(":", aws_db_instance.mssql.endpoint)[0] },
        { name = "DB_PORT", value = tostring(var.mssql_port) },
        { name = "DB_LIST", value = join(" ", var.mssql_databases) }
      ]

      secrets = [
        { name = "DB_USER", valueFrom = "${local.mssql_master_secret_arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${local.mssql_master_secret_arn}:password::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.db_init[0].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.tags
}

resource "null_resource" "db_init" {
  count = var.run_db_init ? 1 : 0

  # Re-run whenever the database list changes (idempotent: existing DBs are skipped).
  triggers = {
    sql = local.db_init_sql
  }

  depends_on = [aws_db_instance.mssql]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      AWS_REGION = var.aws_region
      CLUSTER    = aws_ecs_cluster.main.name
      TASK_DEF   = aws_ecs_task_definition.db_init[0].arn
      SUBNET     = aws_subnet.private[0].id
      SG         = aws_security_group.ecs.id
    }

    command = <<-EOT
      set -e
      echo "starting db-init task on cluster $CLUSTER ..."
      TASK_ARN=$(aws ecs run-task \
        --cluster "$CLUSTER" \
        --task-definition "$TASK_DEF" \
        --region "$AWS_REGION" \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET],securityGroups=[$SG],assignPublicIp=DISABLED}" \
        --query 'tasks[0].taskArn' \
        --output text)
      if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
        echo "::error::aws ecs run-task returned no task arn"
        exit 1
      fi
      echo "waiting for $TASK_ARN to stop ..."
      aws ecs wait tasks-stopped \
        --cluster "$CLUSTER" \
        --tasks "$TASK_ARN" \
        --region "$AWS_REGION"
      EXIT_CODE=$(aws ecs describe-tasks \
        --cluster "$CLUSTER" \
        --tasks "$TASK_ARN" \
        --region "$AWS_REGION" \
        --query 'tasks[0].containers[0].exitCode' \
        --output text)
      echo "db-init container exit code: $EXIT_CODE"
      [ "$EXIT_CODE" = "0" ]
    EOT
  }
}
