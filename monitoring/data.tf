data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# --- The prod stack's network, read by tag so the two states stay independent -----

data "aws_vpc" "prod" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.prod.id]
  }

  filter {
    name   = "tag:Tier"
    values = [var.private_subnet_tier_tag]
  }
}

data "aws_subnet" "monitoring" {
  id = local.monitor_subnet_id
}

# --- The prod stack's ALB, so Grafana is published without a second load balancer --

data "aws_lb" "main" {
  name = var.alb_name
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.main.arn
  port              = 443
}

data "aws_security_group" "alb" {
  name = var.alb_security_group_name
}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}
