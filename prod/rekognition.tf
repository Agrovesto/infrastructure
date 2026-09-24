# =============================================================================
# Amazon Rekognition: every feature the apps use.
#
# * Image analysis (labels, text, moderation, faces, PPE, celebrities, custom
#   labels inference): stateless API calls, so only IAM is needed.
# * Face collections (KYC: index a customer's face, then search or compare
#   later): aws_rekognition_collection.this, one per var.rekognition.collections.
# * Face Liveness: the backend creates the session and reads the result. The
#   browser/mobile SDK streams the video with Cognito guest credentials that
#   can do nothing except StartFaceLivenessSession. Audit images go to the
#   media bucket under liveness/ and expire.
# * Video analysis (Start*/Get* async jobs): Rekognition publishes job
#   completion to an SNS topic through its own role. The topic fans out to an
#   SQS queue the backend polls.
#
# Media bucket: uploads the APIs pass to Rekognition by S3 reference. Rekognition
# reads with the caller's credentials, so SSE-S3 is used (SSE-KMS would add a key
# grant to every call for no gain here).
# =============================================================================

locals {
  rekognition_name   = "${local.name}-rekognition"
  rekognition_bucket = "${local.name}-rekognition-${data.aws_caller_identity.current.account_id}"
}

# --- Face collections ---------------------------------------------------------
resource "aws_rekognition_collection" "this" {
  for_each      = toset(var.rekognition.collections)
  collection_id = "${local.name}-${each.key}"
  tags          = local.tags
}

# --- Media bucket -------------------------------------------------------------
resource "aws_s3_bucket" "rekognition" {
  bucket = local.rekognition_bucket
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "rekognition" {
  bucket                  = aws_s3_bucket.rekognition.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "rekognition" {
  bucket = aws_s3_bucket.rekognition.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rekognition" {
  bucket = aws_s3_bucket.rekognition.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "rekognition" {
  bucket = aws_s3_bucket.rekognition.id

  rule {
    id     = "expire-liveness-audit-images"
    status = "Enabled"
    filter {
      prefix = "liveness/"
    }
    expiration {
      days = var.rekognition.liveness_retention_days
    }
  }

  rule {
    id     = "expire-uploads"
    status = "Enabled"
    filter {
      prefix = "uploads/"
    }
    expiration {
      days = var.rekognition.upload_retention_days
    }
  }

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "rekognition" {
  bucket = aws_s3_bucket.rekognition.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.rekognition.arn, "${aws_s3_bucket.rekognition.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.rekognition]
}

# --- Video analysis: job completion -> SNS -> SQS -----------------------------
resource "aws_sns_topic" "rekognition_video" {
  name              = "${local.rekognition_name}-video"
  kms_master_key_id = aws_kms_key.sns.arn
  tags              = local.tags
}

resource "aws_sqs_queue" "rekognition_video_dlq" {
  name                      = "${local.rekognition_name}-video-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  tags                      = local.tags
}

resource "aws_sqs_queue" "rekognition_video" {
  name                       = "${local.rekognition_name}-video"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.rekognition_video_dlq.arn
    maxReceiveCount     = 5
  })
  tags = local.tags
}

resource "aws_sqs_queue_policy" "rekognition_video" {
  queue_url = aws_sqs_queue.rekognition_video.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "FromVideoTopic"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.rekognition_video.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.rekognition_video.arn } }
    }]
  })
}

resource "aws_sns_topic_subscription" "rekognition_video" {
  topic_arn            = aws_sns_topic.rekognition_video.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.rekognition_video.arn
  raw_message_delivery = true
}

# Rekognition assumes this to publish job status (passed as
# NotificationChannel.RoleArn on every Start* video call).
resource "aws_iam_role" "rekognition_video" {
  name = "${local.rekognition_name}-video"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rekognition.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "rekognition_video" {
  name = "publish-job-status"
  role = aws_iam_role.rekognition_video.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "sns:Publish", Resource = aws_sns_topic.rekognition_video.arn },
      { Effect = "Allow", Action = ["kms:GenerateDataKey*", "kms:Decrypt"], Resource = aws_kms_key.sns.arn }
    ]
  })
}

# --- Face Liveness: guest credentials for the client SDK ----------------------
resource "aws_cognito_identity_pool" "liveness" {
  count                            = var.rekognition.liveness_identity_pool ? 1 : 0
  identity_pool_name               = replace("${local.name}_liveness", "-", "_")
  allow_unauthenticated_identities = true
  allow_classic_flow               = false
  tags                             = local.tags
}

resource "aws_iam_role" "liveness_guest" {
  count = var.rekognition.liveness_identity_pool ? 1 : 0
  name  = "${local.rekognition_name}-liveness-guest"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = "cognito-identity.amazonaws.com" }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals             = { "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.liveness[0].id }
        "ForAnyValue:StringLike" = { "cognito-identity.amazonaws.com:amr" = "unauthenticated" }
      }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "liveness_guest" {
  count = var.rekognition.liveness_identity_pool ? 1 : 0
  name  = "start-liveness-stream"
  role  = aws_iam_role.liveness_guest[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "rekognition:StartFaceLivenessSession"
      Resource = "*"
    }]
  })
}

resource "aws_cognito_identity_pool_roles_attachment" "liveness" {
  count            = var.rekognition.liveness_identity_pool ? 1 : 0
  identity_pool_id = aws_cognito_identity_pool.liveness[0].id
  roles = {
    unauthenticated = aws_iam_role.liveness_guest[0].arn
  }
}

# --- What the application may do ---------------------------------------------
resource "aws_iam_role_policy" "app_rekognition" {
  name = "${local.name}-app-rekognition"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Stateless analysis, liveness sessions, video jobs and custom-label
        # inference. These actions do not support resource-level scoping.
        Sid    = "Analysis"
        Effect = "Allow"
        Action = [
          "rekognition:Detect*",
          "rekognition:CompareFaces",
          "rekognition:RecognizeCelebrities",
          "rekognition:GetCelebrityInfo",
          "rekognition:CreateFaceLivenessSession",
          "rekognition:GetFaceLivenessSessionResults",
          "rekognition:StartLabelDetection",
          "rekognition:StartFaceDetection",
          "rekognition:StartContentModeration",
          "rekognition:StartTextDetection",
          "rekognition:StartPersonTracking",
          "rekognition:StartCelebrityRecognition",
          "rekognition:StartSegmentDetection",
          "rekognition:Get*Detection",
          "rekognition:GetContentModeration",
          "rekognition:GetPersonTracking",
          "rekognition:GetCelebrityRecognition",
          "rekognition:GetFaceSearch",
          "rekognition:DescribeProjects",
          "rekognition:DescribeProjectVersions"
        ]
        Resource = "*"
      },
      {
        Sid    = "FaceCollections"
        Effect = "Allow"
        Action = [
          "rekognition:IndexFaces",
          "rekognition:SearchFaces",
          "rekognition:SearchFacesByImage",
          "rekognition:SearchUsers",
          "rekognition:SearchUsersByImage",
          "rekognition:ListFaces",
          "rekognition:DeleteFaces",
          "rekognition:DescribeCollection",
          "rekognition:CreateUser",
          "rekognition:DeleteUser",
          "rekognition:ListUsers",
          "rekognition:AssociateFaces",
          "rekognition:DisassociateFaces",
          "rekognition:StartFaceSearch"
        ]
        Resource = length(aws_rekognition_collection.this) > 0 ? [for c in aws_rekognition_collection.this : c.arn] : ["arn:aws:rekognition:${var.aws_region}:${data.aws_caller_identity.current.account_id}:collection/none"]
      },
      {
        Sid      = "MediaBucket"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.rekognition.arn}/*"
      },
      {
        Sid      = "MediaBucketList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.rekognition.arn
      },
      {
        Sid      = "PassVideoRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.rekognition_video.arn
        Condition = { StringEquals = { "iam:PassedToService" = "rekognition.amazonaws.com" } }
      },
      {
        Sid      = "VideoResults"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.rekognition_video.arn
      }
    ]
  })
}
