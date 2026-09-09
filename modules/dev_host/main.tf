locals {
  active_services      = var.services_enabled ? var.services : {}
  prefix               = "${var.name}-${var.account_id}-${var.region}"
  secret_arns          = concat([aws_secretsmanager_secret.admin.arn], values(var.database_secret_arns))
  external_secret_arns = distinct(flatten([for s in values(local.active_services) : [for arn in values(s.secrets) : join(":", slice(split(":", arn), 0, 7))]]))
}
module "artifacts" {
  source            = "../storage"
  name              = "${local.prefix}-artifacts"
  kms_key_arn       = var.kms_key_arn
  access_log_bucket = var.access_log_bucket
}
module "backups" {
  source            = "../storage"
  name              = "${local.prefix}-sql-backups"
  kms_key_arn       = var.kms_key_arn
  access_log_bucket = var.access_log_bucket
  expiration_days   = 35
  noncurrent_days   = 35
  object_lock_days  = 7
}
resource "aws_secretsmanager_secret" "admin" {
  #checkov:skip=CKV2_AWS_57:Dev sa rotation needs a coordinated SQL/password change; use the manual runbook, not an unsafe independent secret rotation.

  name                    = "${var.project}/dev/sql/admin"
  description             = "Dev SQL Server sa login; generated at runtime, not in Terraform state"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_cloudwatch_log_group" "host" {
  name              = "/${var.name}/host"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}
resource "aws_cloudwatch_log_group" "containers" {
  name              = "/${var.name}/containers"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}
resource "aws_iam_role" "this" {
  name                 = "${var.name}-host"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "this" {
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken", "secretsmanager:GetRandomPassword"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"], Resource = var.ecr_repository_arns },
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:PutSecretValue"], Resource = local.secret_arns },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"], Resource = var.kms_key_arn },
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = module.artifacts.arn, Condition = { StringLike = { "s3:prefix" = ["releases/*"] } } },
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${module.artifacts.arn}/releases/*" },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload"], Resource = "${module.backups.arn}/sqlserver/*" },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = ["${aws_cloudwatch_log_group.host.arn}:*", "${aws_cloudwatch_log_group.containers.arn}:*"] },
      { Effect = "Allow", Action = ["ec2:DescribeTags", "logs:DescribeLogGroups"], Resource = "*" },
      { Effect = "Allow", Action = ["cloudwatch:PutMetricData"], Resource = "*", Condition = { StringEquals = { "cloudwatch:namespace" = ["${var.project}/System", "${var.project}/Backups"] } } }
      ], length(local.external_secret_arns) == 0 ? [] : [
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = local.external_secret_arns }
    ])
  })
}
resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-host"
  role = aws_iam_role.this.name
}
resource "aws_security_group" "this" {
  name        = "${var.name}-host"
  description = "Private Compose host; no SSH, no exposed SQL Server"
  vpc_id      = var.vpc_id
}
resource "aws_vpc_security_group_ingress_rule" "api" {
  for_each                     = var.services
  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.alb_security_group_id
  description                  = "ALB to ${each.key} only"
  ip_protocol                  = "tcp"
  from_port                    = each.value.host_port
  to_port                      = each.value.host_port
}
resource "aws_vpc_security_group_egress_rule" "alb" {
  for_each                     = var.services
  security_group_id            = var.alb_security_group_id
  referenced_security_group_id = aws_security_group.this.id
  description                  = "ALB to ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = each.value.host_port
  to_port                      = each.value.host_port
}
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.this.id
  description       = "HTTPS via NAT for SSM, registries, packages and application dependencies"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
resource "aws_ebs_volume" "database" {
  availability_zone = var.availability_zone
  size              = var.database_volume_size
  type              = "gp3"
  # OPTIMIZED: baseline gp3 (3000 IOPS / 125 MB/s) – cheapest that still meets SQL Server needs; raise only on metrics.
  iops              = 3000
  throughput        = 125
  encrypted         = true
  kms_key_id        = var.kms_key_arn
  tags              = { Name = "${var.name}-sqlserver-data", Backup = "daily", DataClass = "database" }
  lifecycle {
    prevent_destroy = true
  }
}
data "aws_ami" "this" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}
resource "aws_instance" "this" {
  ami                         = var.ami_id == null ? data.aws_ami.this[0].id : var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  monitoring                  = true
  ebs_optimized               = true
  disable_api_termination     = true
  user_data_replace_on_change = false
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    iops                  = 3000
    throughput            = 125
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
    tags                  = { Name = "${var.name}-os-docker-apis" }
  }
  user_data = <<-USERDATA
    #!/usr/bin/env bash
    set -Eeuo pipefail
    umask 077
    mkdir -p /opt/agrovesto
    export AWS_DEFAULT_REGION=${var.region}
    flock -w 1800 /var/lock/agrovesto-config.lock bash -c '
      aws s3 cp s3://${module.artifacts.id}/releases/${local.release_hash}/ /opt/agrovesto/ --recursive --only-show-errors
      bash /opt/agrovesto/install.sh
    '
  USERDATA
  tags      = { Name = "${var.name}-compose" }
  lifecycle {
    # Do AMI upgrades by a deliberate maintenance replacement, not by a routine plan.
    ignore_changes = [ami]
    precondition {
      condition     = var.accept_sqlserver_eula
      error_message = "Accept Microsoft's SQL Server EULA explicitly. Developer edition is for non-production use only."
    }
  }
  depends_on = [aws_s3_object.release, aws_iam_role_policy.this, aws_iam_role_policy_attachment.ssm]
}
resource "aws_volume_attachment" "database" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.database.id
  instance_id                    = aws_instance.this.id
  force_detach                   = false
  stop_instance_before_detaching = true
}
resource "aws_ssm_document" "configure" {
  name            = "${var.name}-configure"
  document_type   = "Command"
  document_format = "JSON"
  content = jsonencode({
    schemaVersion = "2.2", description = "Converge versioned Compose configuration; no secrets in this document"
    parameters = {
      Bucket = { type = "String", allowedPattern = "^[a-z0-9.-]+$" }
      Prefix = { type = "String", allowedPattern = "^releases/[a-f0-9]{64}$" }
    }
    mainSteps = [{ action = "aws:runShellScript", name = "Configure", inputs = {
      timeoutSeconds = "2400"
      runCommand = [
        "set -eu", "mkdir -p /opt/agrovesto",
        "export AWS_DEFAULT_REGION=${var.region}",
        "flock -w 1800 /var/lock/agrovesto-config.lock bash -c 'aws s3 cp s3://{{ Bucket }}/{{ Prefix }}/ /opt/agrovesto/ --recursive --only-show-errors && bash /opt/agrovesto/install.sh'"
      ]
    } }]
  })
}
resource "aws_ssm_association" "configure" {
  name                     = aws_ssm_document.configure.name
  association_name         = "${var.name}-configure"
  document_version         = aws_ssm_document.configure.latest_version
  wait_for_success_timeout = "45m"
  parameters               = { Bucket = module.artifacts.id, Prefix = "releases/${local.release_hash}" }
  targets {
    key    = "InstanceIds"
    values = [aws_instance.this.id]
  }
  depends_on = [aws_volume_attachment.database, aws_s3_object.release]
}
