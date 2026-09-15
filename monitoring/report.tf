# Monthly cost, usage and analysis report: the previous month is aggregated from
# the Cost and Usage Report by a scheduled task, rendered as a PDF and mailed
# through SES. The sending domain is verified here (DKIM included) so the whole
# feature is Terraform-managed and needs no manual console step.

locals {
  report_ses_domain = var.report_ses_domain != "" ? var.report_ses_domain : var.domain_name
  report_sender     = var.report_sender != "" ? var.report_sender : "monitoring@${local.report_ses_domain}"
  report_recipients = length(var.report_recipients) > 0 ? var.report_recipients : (var.alert_email != "" ? [var.alert_email] : [])
  report_enabled    = var.enable_monthly_report && var.enable_cost_monitoring && length(local.report_recipients) > 0
  report_script_key = "scripts/monthly_report.py"

  report_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.monitoring.name
      awslogs-region        = var.aws_region
      awslogs-stream-prefix = "report"
    }
  }
}

resource "aws_ses_domain_identity" "monthly_report" {
  count = local.report_enabled ? 1 : 0

  domain = local.report_ses_domain
}

resource "aws_route53_record" "monthly_report_verification" {
  count = local.report_enabled ? 1 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "_amazonses.${local.report_ses_domain}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.monthly_report[0].verification_token]
}

resource "aws_ses_domain_dkim" "monthly_report" {
  count = local.report_enabled ? 1 : 0

  domain = aws_ses_domain_identity.monthly_report[0].domain
}

resource "aws_route53_record" "monthly_report_dkim" {
  count = local.report_enabled ? 3 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${aws_ses_domain_dkim.monthly_report[0].dkim_tokens[count.index]}._domainkey.${local.report_ses_domain}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.monthly_report[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_s3_object" "report_script" {
  count = local.report_enabled ? 1 : 0

  provider = aws.us_east_1
  bucket   = aws_s3_bucket.cur[0].id
  key      = local.report_script_key
  content  = file("${path.module}/scripts/monthly_report.py")
  etag     = filemd5("${path.module}/scripts/monthly_report.py")
}

resource "aws_ecs_task_definition" "report" {
  count = local.report_enabled ? 1 : 0

  family                   = "${local.name}-report"
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
    name      = "report"
    image     = local.images.budget
    essential = true

    command = [
      "sh",
      "-c",
      "pip install --quiet --no-cache-dir duckdb boto3 fpdf2 && python -c \"import boto3,os;boto3.client('s3', region_name='us-east-1').download_file(os.environ['SCRIPT_BUCKET'], os.environ['SCRIPT_KEY'], '/tmp/monthly_report.py')\" && python /tmp/monthly_report.py",
    ]

    environment = [
      { name = "SCRIPT_BUCKET", value = aws_s3_bucket.cur[0].bucket },
      { name = "SCRIPT_KEY", value = local.report_script_key },
      { name = "CUR_BUCKET", value = aws_s3_bucket.cur[0].bucket },
      { name = "CUR_PREFIX", value = local.cur_prefix },
      { name = "CUR_REPORT_NAME", value = var.cur_report_name },
      { name = "CUR_REGION", value = "us-east-1" },
      { name = "BUDGET_USD", value = tostring(var.monthly_budget_usd) },
      { name = "REPORT_RECIPIENTS", value = join(",", local.report_recipients) },
      { name = "REPORT_SENDER", value = local.report_sender },
      { name = "SES_REGION", value = var.aws_region },
      { name = "PUSHGATEWAY_URL", value = local.endpoints.pushgateway },
    ]

    logConfiguration = local.report_log_config
  }])

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "report" {
  count = local.report_enabled ? 1 : 0

  name                = "${local.name}-report"
  description         = "Runs the monthly cost/usage/analysis report task"
  schedule_expression = var.report_schedule_expression

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "report" {
  count = local.report_enabled ? 1 : 0

  rule     = aws_cloudwatch_event_rule.report[0].name
  arn      = aws_ecs_cluster.monitoring.arn
  role_arn = aws_iam_role.events[0].arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.report[0].arn
    launch_type         = "FARGATE"
    platform_version    = "1.4.0"

    network_configuration {
      subnets          = [local.monitor_subnet_id]
      security_groups  = [aws_security_group.internal.id]
      assign_public_ip = false
    }
  }
}
