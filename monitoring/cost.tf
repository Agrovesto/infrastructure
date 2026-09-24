# Cost and budget reporting without any AWS cost-management tooling:
# a Cost and Usage Report lands in S3, a daily Fargate task aggregates it with
# DuckDB and pushes the numbers to Pushgateway, where Prometheus picks them up.

locals {
  cur_bucket        = var.cur_bucket_name != "" ? var.cur_bucket_name : "${local.name}-cur-${data.aws_caller_identity.current.account_id}"
  cur_prefix        = "cur"
  budget_script_key = "scripts/budget_report.py"

  budget_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.monitoring.name
      awslogs-region        = var.aws_region
      awslogs-stream-prefix = "budget"
    }
  }
}

resource "aws_s3_bucket" "cur" {
  #checkov:skip=CKV_AWS_21: CUR delivery overwrites its own objects; versioning would only add storage cost
  count = var.enable_cost_monitoring ? 1 : 0

  provider = aws.us_east_1
  bucket   = local.cur_bucket

  tags = merge(local.tags, { Name = local.cur_bucket })
}

resource "aws_s3_bucket_public_access_block" "cur" {
  count = var.enable_cost_monitoring ? 1 : 0

  provider = aws.us_east_1
  bucket   = aws_s3_bucket.cur[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cur" {
  #checkov:skip=CKV_AWS_145: SSE-S3 - a CMK would have to live in us-east-1 as well, for a bucket that only holds the cost report
  count = var.enable_cost_monitoring ? 1 : 0

  provider = aws.us_east_1
  bucket   = aws_s3_bucket.cur[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cur" {
  count = var.enable_cost_monitoring ? 1 : 0

  provider = aws.us_east_1
  bucket   = aws_s3_bucket.cur[0].id

  rule {
    id     = "expire-old-reports"
    status = "Enabled"

    filter {}

    expiration {
      days = 400
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# The billing service writes the report; nothing else may.
resource "aws_s3_bucket_policy" "cur" {
  count = var.enable_cost_monitoring ? 1 : 0

  provider = aws.us_east_1
  bucket   = aws_s3_bucket.cur[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTls"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = ["arn:aws:s3:::${local.cur_bucket}", "arn:aws:s3:::${local.cur_bucket}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "AllowBillingReports"
        Effect    = "Allow"
        Principal = { Service = "billingreports.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:GetBucketPolicy"]
        Resource  = "arn:aws:s3:::${local.cur_bucket}"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cur:us-east-1:${data.aws_caller_identity.current.account_id}:definition/*"
          }
        }
      },
      {
        Sid       = "AllowBillingReportsPut"
        Effect    = "Allow"
        Principal = { Service = "billingreports.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::${local.cur_bucket}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cur:us-east-1:${data.aws_caller_identity.current.account_id}:definition/*"
          }
        }
      }
    ]
  })
}

resource "aws_cur_report_definition" "daily" {
  count = var.enable_cost_monitoring ? 1 : 0

  # CUR definitions only exist in us-east-1.
  provider = aws.us_east_1

  report_name                = var.cur_report_name
  time_unit                  = "DAILY"
  format                     = "Parquet"
  compression                = "Parquet"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                  = aws_s3_bucket.cur[0].bucket
  s3_prefix                  = local.cur_prefix
  s3_region                  = "us-east-1"
  report_versioning          = "OVERWRITE_REPORT"
}

resource "aws_s3_object" "budget_script" {
  count = var.enable_cost_monitoring ? 1 : 0

  provider = aws.us_east_1
  bucket   = aws_s3_bucket.cur[0].id
  key      = local.budget_script_key
  content  = file("${path.module}/scripts/budget_report.py")
  etag     = filemd5("${path.module}/scripts/budget_report.py")
}

resource "aws_ecs_task_definition" "budget" {
  count = var.enable_cost_monitoring ? 1 : 0

  family                   = "${local.name}-budget"
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name      = "budget"
    image     = local.images.budget
    essential = true

    command = [
      "sh",
      "-c",
      "pip install --quiet --no-cache-dir duckdb boto3 && python -c \"import boto3,os;boto3.client('s3', region_name='us-east-1').download_file(os.environ['SCRIPT_BUCKET'], os.environ['SCRIPT_KEY'], '/tmp/budget_report.py')\" && python /tmp/budget_report.py",
    ]

    environment = [
      { name = "SCRIPT_BUCKET", value = aws_s3_bucket.cur[0].bucket },
      { name = "SCRIPT_KEY", value = local.budget_script_key },
      { name = "CUR_BUCKET", value = aws_s3_bucket.cur[0].bucket },
      { name = "CUR_PREFIX", value = local.cur_prefix },
      { name = "CUR_REPORT_NAME", value = var.cur_report_name },
      { name = "CUR_REGION", value = "us-east-1" },
      { name = "BUDGET_USD", value = tostring(var.monthly_budget_usd) },
      { name = "PUSHGATEWAY_URL", value = local.endpoints.pushgateway },
    ]

    logConfiguration = local.budget_log_config
  }])

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "budget" {
  count = var.enable_cost_monitoring ? 1 : 0

  name                = "${local.name}-budget"
  description         = "Runs the daily cost/budget aggregation task"
  schedule_expression = var.budget_schedule_expression

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "budget" {
  count = var.enable_cost_monitoring ? 1 : 0

  rule     = aws_cloudwatch_event_rule.budget[0].name
  arn      = aws_ecs_cluster.monitoring.arn
  role_arn = aws_iam_role.events[0].arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.budget[0].arn
    launch_type         = "FARGATE"
    platform_version    = "1.4.0"

    network_configuration {
      subnets          = [local.monitor_subnet_id]
      security_groups  = [aws_security_group.internal.id]
      assign_public_ip = false
    }
  }
}
