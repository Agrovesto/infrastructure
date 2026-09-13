# =============================================================================
# RDS SQL Server — one Multi-AZ instance hosting the same 5 databases as dev
# (wallet, onboarding, input, moneval, serviceprovider).
#
# Credentials: generated here (never in GitHub secrets), stored in Secrets
# Manager as JSON { username, password, host, port } and injected into the ECS
# tasks as DB_USER / DB_PASSWORD.
#
# Databases: RDS cannot create databases via the aws_db_instance resource, so
# when var.run_db_init = true a one-off Fargate task runs `CREATE DATABASE`
# for every name in var.mssql_databases (triggered from the CI runner through
# the AWS API — the runner itself needs no VPC access). Runbook SQL is also
# printed in the `mssql_db_init_sql` output for manual use.
# =============================================================================

resource "random_password" "mssql_master" {
  length           = 32
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  # RDS SQL Server: any printable ASCII except /, ", @ and space.
  override_special = "!#$%^&*()-_=+[]{}<>:;?"
}

resource "aws_secretsmanager_secret" "mssql_master" {
  name                    = "${local.name}-mssql-master"
  description             = "Master credentials for the ${local.name} RDS SQL Server instance"
  recovery_window_in_days = 7 # prod: keep a restore window in case of accidental deletes

  tags = merge(local.tags, { Name = "${local.name}-mssql-master" })
}

resource "aws_secretsmanager_secret_version" "mssql_master" {
  secret_id     = aws_secretsmanager_secret.mssql_master.id
  secret_string = jsonencode({
    username = var.mssql_master_username
    password = random_password.mssql_master.result
    engine   = "sqlserver"
    host     = split(":", aws_db_instance.mssql.endpoint)[0]
    port     = var.mssql_port
    dbname   = ""
  })
}

resource "aws_db_instance" "mssql" {
  identifier = "${local.name}-mssql"

  engine               = var.mssql_engine
  engine_version       = var.mssql_engine_version
  instance_class       = var.mssql_instance_class
  parameter_group_name = null # default parameter group; add a custom one when needed

  allocated_storage     = var.mssql_allocated_storage_gb
  max_allocated_storage = var.mssql_max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.mssql.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = var.mssql_port

  username = var.mssql_master_username
  password = random_password.mssql_master.result

  multi_az = var.mssql_multi_az

  backup_retention_period = var.mssql_backup_retention_days
  backup_window           = "03:00-04:00"      # UTC
  maintenance_window      = "sun:04:30-sun:05:30" # UTC, outside the backup window
  copy_tags_to_snapshot   = true

  skip_final_snapshot       = var.mssql_skip_final_snapshot
  final_snapshot_identifier = var.mssql_skip_final_snapshot ? null : "${local.name}-mssql-final-snapshot"
  deletion_protection       = var.deletion_protection

  # Enhanced monitoring + log exports (agent + error logs to CloudWatch) +
  # Performance Insights (free 7-day retention tier).
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports       = ["agent", "error"]
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(local.tags, { Name = "${local.name}-mssql" })
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
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

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
        { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.mssql_master.arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.mssql_master.arn}:password::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options   = {
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
