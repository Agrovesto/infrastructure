# Host config bucket ----------------------------------------------------------
#
# One object per rendered file, keyed by the path that file has on the host
# (local.host_config_files). Same shape as the prod monitoring stack, which keeps
# its Prometheus/Loki/Alloy config in S3 and syncs it on boot.
#
# It is *config*, not data: nothing the stack writes lives here. So when a change
# to a .tftpl replaces the instance, user_data re-syncs the objects while Loki's
# chunks, the Prometheus TSDB and Grafana's sqlite ride out the replacement on
# aws_ebs_volume.logging.
#
# The bucket is unconditional, unlike the logging volume: the compose project and
# nginx.conf are delivered through it on every boot, logging stack or not.
resource "aws_kms_key" "host_passwords" {
  description         = "${local.name} host passwords in SSM"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowAccountIamPolicies"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  tags = local.tags
}

resource "aws_ssm_parameter" "mssql_sa_password" {
  name   = "/${local.name}/mssql_sa_password"
  type   = "SecureString"
  value  = var.mssql_sa_password
  key_id = aws_kms_key.host_passwords.arn
  tags   = local.tags
}

resource "aws_ssm_parameter" "grafana_admin_password" {
  count = var.logging.enabled ? 1 : 0

  name   = "/${local.name}/grafana_admin_password"
  type   = "SecureString"
  value  = var.logging.grafana_admin_password
  key_id = aws_kms_key.host_passwords.arn
  tags   = local.tags
}

resource "aws_s3_bucket" "host_config" {
  # "dev-" prefix comes from local.name, so the prod stack can never write here.
  bucket = local.host_config_bucket

  # Config is reproducible from this repository at any time, so an accidental
  # destroy of the bucket is an inconvenience, not a loss: dev may empty it.
  force_destroy = true

  tags = merge(local.tags, {
    Name    = "${local.name}-host-config"
    Purpose = "host-config"
  })
}

resource "aws_s3_bucket_public_access_block" "host_config" {
  bucket = aws_s3_bucket.host_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "host_config" {
  bucket = aws_s3_bucket.host_config.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 like the backup bucket: these are rendered config files, no secrets, and
# no CMK in dev (checkov CKV_AWS_145 is skipped module-wide for that reason).
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "host_config" {
  bucket = aws_s3_bucket.host_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning makes a bad config edit recoverable; it just must not pile up.
resource "aws_s3_bucket_lifecycle_configuration" "host_config" {
  bucket = aws_s3_bucket.host_config.id

  rule {
    id     = "prune-noncurrent-config"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Every value here is already in Terraform state (it is derived from tfvars and
# module output), so the objects leak nothing the state file does not already
# hold. What must never land here is a secret: the Grafana admin password and the
# SA password go into the host's .env from user_data and are not objects.
# HTTPS-only: deny any request made over plain HTTP (Sonar S6249).
# HTTPS-only: deny any request made over plain HTTP (Sonar S6249).

resource "aws_s3_object" "host_config" {
  for_each = local.host_config_files

  bucket  = aws_s3_bucket.host_config.bucket
  key     = each.key
  content = each.value.content

  content_type = each.value.content_type
  etag         = md5(each.value.content)

  tags = local.tags

  # Versioning has to exist before the first write, or these keys land as
  # unversioned versions that no history can later prune.
  depends_on = [aws_s3_bucket_versioning.host_config]
}


# HTTPS-only: deny any request made over plain HTTP (Sonar S6249).
resource "aws_s3_bucket_policy" "host_config" {
  bucket = aws_s3_bucket.host_config.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.host_config.arn, "${aws_s3_bucket.host_config.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.host_config]
}