# =============================================================================
# S3 — versioned, encrypted bucket for nightly MSSQL backups
# =============================================================================

resource "aws_s3_bucket" "backup" {
  bucket        = "${local.name}-mssql-backups"
  force_destroy = var.backup_force_destroy

  tags = merge(local.tags, {
    Name    = "${local.name}-mssql-backups"
    Purpose = "mssql-backup"
  })
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES256) is sufficient for dev backups; use a KMS CMK for prod - mirrors checkov CKV_AWS_145 skip.
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
