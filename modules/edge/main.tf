# Public edge: Application Load Balancer with HTTPS (and HTTP→HTTPS redirect).
# WAF is intentionally not provisioned (cost). Application auth/rate-limits remain required.
resource "aws_security_group" "this" {
  name        = "${var.name}-alb"
  description = "Public HTTPS and HTTP-to-HTTPS redirect; egress granted only to service security groups"
  vpc_id      = var.vpc_id
}
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.this.id
  description       = "Public TLS endpoint"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "redirect" {
  #checkov:skip=CKV_AWS_260:Port 80 serves only the ALB HTTPS redirect; no application listener serves plaintext.

  security_group_id = aws_security_group.this.id
  description       = "Only an HTTP-to-HTTPS redirect, never application traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}
resource "aws_lb" "this" {
  #checkov:skip=CKV2_AWS_76:WAF is intentionally omitted for cost; the ALB remains the sole public ingress with TLS, header drop and strict desync mitigation.

  name                       = var.name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.this.id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = true
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "strictest"
  access_logs {
    bucket  = var.access_log_bucket
    prefix  = "alb"
    enabled = true
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
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
}
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Unknown service"
      status_code  = "404"
    }
  }
}
resource "aws_cloudwatch_metric_alarm" "server_errors" {
  alarm_name          = "${var.name}-alb-target-5xx"
  alarm_description   = "Inspect application logs and the target health dashboard."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = aws_lb.this.arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alerts_topic_arn]
  ok_actions          = [var.alerts_topic_arn]
}
