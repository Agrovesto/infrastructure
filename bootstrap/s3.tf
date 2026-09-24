# =============================================================================
# S3 — Terraform state bucket (referenced by ../prod/versions.tf backend block)
# =============================================================================

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18: state bucket doesn't need access logging (a second log bucket would be circular here)
  #checkov:skip=CKV_AWS_144: cross-region replication isn't needed for state (versioning + 30d noncurrent retention is enough)
  #checkov:skip=CKV_AWS_145: SSE-S3 (AES256), same as the dev state bucket
  #checkov:skip=CKV2_AWS_62: no event consumers on the state bucket
  bucket        = local.state_bucket_name
  force_destroy = false

  tags = merge(local.tags, {
    Name    = local.state_bucket_name
    Purpose = "terraform-state"
  })
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      # AES256 by default; set var.state_bucket_kms_key_arn to keep an existing
      # bucket's SSE-KMS key when importing it.
      sse_algorithm     = var.state_bucket_kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.state_bucket_kms_key_arn != "" ? var.state_bucket_kms_key_arn : null
    }
    bucket_key_enabled = var.state_bucket_kms_key_arn != "" ? true : null
  }
}

# Old noncurrent state versions expire after var.state_noncurrent_days (default 30).
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = var.state_lifecycle_rule_id
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = var.state_noncurrent_days
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json
}
