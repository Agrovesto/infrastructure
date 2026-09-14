# =============================================================================
# ALB — internet-facing, public subnets, HTTPS (ACM cert), host-header routing
#
#   https://wallet-api.nomaos.com          -> wallet tasks (private subnets)
#   https://onboarding-api.nomaos.com  -> onboarding tasks
#   https://input-api.nomaos.com           -> input tasks
#   https://moneval-api.nomaos.com         -> moneval tasks
#   https://serviceprovider-api.nomaos.com -> serviceprovider tasks
#
# HTTP (80) only exists to redirect to HTTPS.
# =============================================================================

# -- Access logs bucket --------------------------------------------------------

# AES256 + no self-logging + no cross-region replication (log bucket; lifecycle keeps 90d) - mirrors checkov CKV_AWS_145/CKV_AWS_18/CKV_AWS_144 skips.
#trivy:ignore:AVD-AWS-0132
#trivy:ignore:AVD-AWS-0089
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${local.name}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  tags = merge(local.tags, {
    Name    = "${local.name}-alb-logs"
    Purpose = "alb-access-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-old-alb-logs"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = var.alb_logs_retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = can(jsondecode(data.aws_iam_policy_document.alb_logs.json)) ? data.aws_iam_policy_document.alb_logs.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
}

# -- Load balancer --------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  internal           = false

  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]
  ip_address_type    = "ipv4"
  idle_timeout       = var.alb_idle_timeout_seconds

  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection

  # TLS listener terminates SSL; WAF is a cost/rules decision for later - checkov CKV2_AWS_28.
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.alb_logs]

  tags = merge(local.tags, { Name = "${local.name}-alb" })
}

# -- Target groups (one per service, ip targets for Fargate) -------------------

resource "aws_lb_target_group" "services" {
  for_each = var.services

  # 32-char name limit: "agrovesto-prod-serviceprovider" == 30 chars.
  name                 = "${local.name}-${each.key}"
  port                 = each.value.port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    path                = each.value.health_check_path
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.tags, { Service = each.key })
}

# -- Listeners -------------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.alb_tls_policy
  certificate_arn   = aws_acm_certificate_validation.wildcard.certificate_arn

  # Anything that isn't one of our service subdomains gets a 404.
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }

  tags = local.tags
}

# Host-header routing: <subdomain>.<domain> -> that service's target group.
resource "aws_lb_listener_rule" "services" {
  for_each = var.services

  listener_arn = aws_lb_listener.https.arn
  priority     = index(sort(keys(var.services)), each.key) + 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    host_header {
      values = [local.service_fqdns[each.key]]
    }
  }

  tags = merge(local.tags, { Service = each.key })
}
