# Configuration delivery.
#
# Config files are rendered in locals / read from disk and published as S3
# objects; a small aws-cli init container syncs them into <mount>/config inside
# each task, so no custom images are needed and payloads are not capped by the
# SSM parameter size limit.
#
#   S3: s3://<bucket>/config/<relative path>  ->  <mount>/config/<relative path>
#
# Changing a value here needs a service redeploy to take effect
# (aws ecs update-service --force-new-deployment).

locals {
  base_config_parameters = {
    "prometheus/prometheus.yml"                        = local.prometheus_config
    "prometheus/rules/platform.yml"                    = local.prometheus_platform_rules
    "prometheus/rules/cost.yml"                        = local.prometheus_cost_rules
    "alertmanager/alertmanager.yml"                    = local.alertmanager_config
    "loki/config.yml"                                  = local.loki_config
    "loki/rules/application.yml"                       = local.loki_rules
    "tempo/config.yml"                                 = local.tempo_config
    "alloy/config.alloy"                               = local.alloy_config
    "blackbox/blackbox.yml"                            = local.blackbox_config
    "grafana/provisioning/datasources/datasources.yml" = local.grafana_datasources
    "grafana/provisioning/dashboards/dashboards.yml"   = local.grafana_dashboards_provider
    "grafana/dashboards/platform.json"                 = file("${path.module}/dashboards/platform.json")
    "grafana/dashboards/services.json"                 = file("${path.module}/dashboards/services.json")
    "grafana/dashboards/cost.json"                     = file("${path.module}/dashboards/cost.json")
  }

  rds_config_parameters = local.mssql_enabled ? {
    "rds/mssql_metrics.py"          = file("${path.module}/scripts/mssql_metrics.py")
    "prometheus/rules/database.yml" = local.prometheus_rds_rules
  } : {}

  collector_config_parameters = local.collector_enabled ? merge({
    "collector/ecs_metrics.py"    = file("${path.module}/scripts/ecs_metrics.py")
    "prometheus/rules/ecs.yml"    = local.prometheus_ecs_rules
    "grafana/dashboards/ecs.json" = file("${path.module}/dashboards/ecs.json")
  }, var.enable_ecs_log_shipping ? {
    "collector/ecs_logs.py" = file("${path.module}/scripts/ecs_logs.py")
  } : {}) : {}

  config_parameters = merge(local.base_config_parameters, local.rds_config_parameters, local.collector_config_parameters)

  config_content_types = {
    json = "application/json"
    yml  = "text/yaml"
  }
}

resource "aws_s3_bucket" "config" {
  bucket = "${local.name}-config-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.tags, { Name = "${local.name}-config" })
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.monitoring.arn
    }

    # Cuts KMS request charges for objects read on every task start.
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    id     = "expire-superseded-config"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyNonTls"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.config.arn, "${aws_s3_bucket.config.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_s3_object" "config" {
  for_each = local.config_parameters

  bucket       = aws_s3_bucket.config.id
  key          = "config/${each.key}"
  content      = each.value
  etag         = md5(each.value)
  content_type = lookup(local.config_content_types, reverse(split(".", each.key))[0], "text/plain")

  tags = local.tags
}

# Generated once and kept in SSM; the container only ever sees it as an
# injected secret (no cleartext in the task definition or in tfvars).
resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "grafana_admin_password" {
  name       = "${local.param}/grafana/admin-password"
  type       = "SecureString"
  value      = random_password.grafana_admin.result
  key_id     = "alias/${local.name}-efs"

  tags = local.tags
}
