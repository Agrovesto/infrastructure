# =============================================================================
# S3 server access logging for every dev bucket (Sonar S6258, Checkov CKV_AWS_18).
#
# One target bucket collects the access logs of the backup, host-config and
# Rekognition media buckets, each under its own prefix. The target bucket uses
# the log-delivery-write ACL (the canonical S3 log target); it does not log
# itself, which would create a feedback loop.
# =============================================================================

locals {
  access_logged_buckets = {
    backup      = aws_s3_bucket.backup.id
    host-config = aws_s3_bucket.host_config.id
    rekognition = aws_s3_bucket.rekognition.id
  }
}

resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV_AWS_18: this IS the access-log target; logging it to itself would loop
  #checkov:skip=CKV2_AWS_62: nothing consumes events from the log bucket
  bucket = "${local.name}-s3-access-logs-${data.aws_caller_identity.current.account_id}"
  tags   = merge(local.tags, { Name = "${local.name}-s3-access-logs" })
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# log-delivery-write needs ACLs enabled with the bucket owner owning objects.
resource "aws_s3_bucket_ownership_controls" "access_logs" {
  #checkov:skip=CKV2_AWS_65: ACLs stay enabled on the log target only, so the S3 log delivery group can write (log-delivery-write)
  bucket = aws_s3_bucket.access_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "access_logs" {
  bucket     = aws_s3_bucket.access_logs.id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.access_logs]
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 log delivery only supports SSE-S3 on the target bucket.
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.s3_access_log_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.access_logs]
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "S3ServerAccessLogsDelivery"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.access_logs.arn}/*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
          ArnLike      = { "aws:SourceArn" = [for b in values(local.access_logged_buckets) : "arn:aws:s3:::${b}"] }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.access_logs.arn, "${aws_s3_bucket.access_logs.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.access_logs]
}

# --- Turn logging on for each bucket --------------------------------------------
resource "aws_s3_bucket_logging" "backup" {
  bucket        = aws_s3_bucket.backup.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "backup/"
}

resource "aws_s3_bucket_logging" "host_config" {
  bucket        = aws_s3_bucket.host_config.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "host-config/"
}

resource "aws_s3_bucket_logging" "rekognition" {
  bucket        = aws_s3_bucket.rekognition.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "rekognition/"
}