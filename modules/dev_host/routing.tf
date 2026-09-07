resource "aws_lb_target_group" "this" {
  #checkov:skip=CKV_AWS_378:TLS terminates at the ALB; HTTP targets are private and SG-restricted. End-to-end app TLS is an explicit hardening extension.

  for_each             = var.services
  name                 = "${substr(var.name, 0, 12)}-${substr(each.key, 0, 10)}-${substr(sha1(each.key), 0, 6)}"
  port                 = each.value.host_port
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = var.vpc_id
  deregistration_delay = 30
  health_check {
    enabled             = true
    path                = each.value.health_path
    matcher             = "200-299"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}
resource "aws_lb_target_group_attachment" "this" {
  for_each         = local.active_services
  target_group_arn = aws_lb_target_group.this[each.key].arn
  target_id        = aws_instance.this.id
  port             = each.value.host_port
}
resource "aws_lb_listener_rule" "this" {
  for_each     = var.services
  listener_arn = var.https_listener_arn
  priority     = each.value.priority
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }
  condition {
    host_header {
      values = [each.value.hostname == "" ? var.zone_name : "${each.value.hostname}.${var.zone_name}"]
    }
  }
}
resource "aws_route53_record" "this" {
  for_each        = var.services
  zone_id         = var.zone_id
  name            = each.value.hostname == "" ? var.zone_name : "${each.value.hostname}.${var.zone_name}"
  type            = "A"
  allow_overwrite = false
  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
resource "aws_cloudwatch_metric_alarm" "unhealthy" {
  for_each            = local.active_services
  alarm_name          = "${var.name}-${each.key}-unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = aws_lb_target_group.this[each.key].arn_suffix }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [var.alerts_topic_arn]
  ok_actions          = [var.alerts_topic_arn]
}
