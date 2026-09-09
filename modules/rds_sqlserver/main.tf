# COST & PERFORMANCE OPTIMIZED: gp3 storage, baseline PI retention 7d, Multi-AZ disabled for dev cost (enable for prod HA via override).
locals {
  identifier = var.identifier == null ? "${var.name}-sqlserver" : var.identifier
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sqlserver"
  description = "SQL Server only from explicitly authorized ECS services and the provisioning task; no outbound rules"
  vpc_id      = var.vpc_id
}
resource "aws_vpc_security_group_ingress_rule" "clients" {
  for_each                     = var.client_security_group_ids
  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  description                  = "SQL Server access from ${each.key}"
  from_port                    = 1433
  to_port                      = 1433
  ip_protocol                  = "tcp"
}
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-sqlserver"
  subnet_ids = var.subnet_ids
}
data "aws_rds_engine_version" "default" {
  count                  = var.engine_version == null ? 1 : 0
  engine                 = "sqlserver-se"
  parameter_group_family = "sqlserver-se-16.0"
  default_only           = true
  latest                 = true
}
resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-sqlserver-"
  family      = "sqlserver-se-16.0"
  description = "SQL Server 2022 Standard; require encrypted client connections"
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_iam_role" "monitoring" {
  name                 = "${var.name}-rds-monitoring"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "monitoring.rds.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
resource "aws_cloudwatch_log_group" "enhanced" {
  name              = "RDSOSMetrics"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}
resource "aws_iam_role" "native_backup" {
  name                 = "${var.name}-rds-native-backup"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "rds.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy" "native_backup" {
  role = aws_iam_role.native_backup.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads"], Resource = var.backup_bucket_arn },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectAttributes", "s3:PutObject", "s3:ListMultipartUploadParts", "s3:AbortMultipartUpload"], Resource = "${var.backup_bucket_arn}/*" },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"], Resource = var.kms_key_arn }
    ]
  })
}
resource "aws_db_option_group" "this" {
  name_prefix          = "${var.name}-sqlserver-"
  engine_name          = "sqlserver-se"
  major_engine_version = "16.00"
  option {
    option_name = "SQLSERVER_BACKUP_RESTORE"
    option_settings {
      name  = "IAM_ROLE_ARN"
      value = aws_iam_role.native_backup.arn
    }
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_iam_role_policy.native_backup]
}
resource "aws_cloudwatch_log_group" "this" {
  for_each          = toset(["error", "agent"])
  name              = "/aws/rds/instance/${local.identifier}/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}
resource "aws_db_instance" "this" {
  identifier     = local.identifier
  engine         = "sqlserver-se"
  engine_version = var.engine_version == null ? data.aws_rds_engine_version.default[0].version : var.engine_version
  license_model  = "license-included"
  instance_class = var.instance_class
  # db_name is NOT supported by RDS SQL Server. The private admin task creates databases.
  username                              = "platform_admin"
  manage_master_user_password           = true
  master_user_secret_kms_key_id         = var.kms_key_arn
  port                                  = 1433
  allocated_storage                     = var.allocated_storage
  max_allocated_storage                 = var.max_allocated_storage
  storage_type                          = "gp3"
  storage_encrypted                     = true
  kms_key_id                            = var.kms_key_arn
  multi_az                              = false
  publicly_accessible                   = false
  db_subnet_group_name                  = aws_db_subnet_group.this.name
  vpc_security_group_ids                = [aws_security_group.this.id]
  parameter_group_name                  = aws_db_parameter_group.this.name
  option_group_name                     = aws_db_option_group.this.name
  backup_retention_period               = 35
  backup_window                         = "01:00-02:00"
  maintenance_window                    = "sun:03:00-sun:04:00"
  auto_minor_version_upgrade            = true
  allow_major_version_upgrade           = false
  apply_immediately                     = false
  deletion_protection                   = true
  skip_final_snapshot                   = false
  final_snapshot_identifier             = var.final_snapshot_identifier
  delete_automated_backups              = false
  copy_tags_to_snapshot                 = true
  enabled_cloudwatch_logs_exports       = ["error", "agent"]
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.monitoring.arn
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn
  performance_insights_retention_period = 7
  database_insights_mode                = "standard"
  ca_cert_identifier                    = "rds-ca-rsa2048-g1"
  timeouts {
    create = "90m"
    update = "90m"
    delete = "90m"
  }
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.allocated_storage >= 50 && var.max_allocated_storage >= var.allocated_storage
      error_message = "Use at least 50 GiB and a storage autoscaling ceiling at or above allocated storage."
    }
  }
  depends_on = [aws_cloudwatch_log_group.this, aws_cloudwatch_log_group.enhanced, aws_iam_role_policy_attachment.monitoring]
}
resource "aws_db_event_subscription" "this" {
  name             = "${var.name}-rds-events"
  sns_topic        = var.alerts_topic_arn
  source_type      = "db-instance"
  source_ids       = [aws_db_instance.this.identifier]
  event_categories = ["availability", "failure", "failover", "low storage", "maintenance", "recovery", "notification"]
}
resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = {
    cpu     = { metric = "CPUUtilization", threshold = 80, operator = "GreaterThanThreshold", statistic = "Average" }
    storage = { metric = "FreeStorageSpace", threshold = 21474836480, operator = "LessThanThreshold", statistic = "Minimum" }
    memory  = { metric = "FreeableMemory", threshold = 536870912, operator = "LessThanThreshold", statistic = "Minimum" }
  }
  alarm_name          = "${var.name}-rds-${each.key}"
  namespace           = "AWS/RDS"
  metric_name         = each.value.metric
  dimensions          = { DBInstanceIdentifier = aws_db_instance.this.identifier }
  statistic           = each.value.statistic
  period              = 300
  evaluation_periods  = 3
  threshold           = each.value.threshold
  comparison_operator = each.value.operator
  treat_missing_data  = "missing"
  alarm_actions       = [var.alerts_topic_arn]
  ok_actions          = [var.alerts_topic_arn]
}
