mock_provider "aws" {}
mock_provider "random" {}

override_data {
  target = data.aws_availability_zones.available
  values = { names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"] }
}
override_data {
  target = data.aws_caller_identity.current
  values = { account_id = "123456789012", arn = "arn:aws:iam::123456789012:root" }
}
override_data {
  target = data.aws_region.current
  values = { name = "eu-west-1" }
}
override_data {
  target = data.aws_elb_service_account.main
  values = { id = "156460612806" }
}
variables {
  import_existing = false
  rabbitmq = {
    enabled       = true
    allowed_cidrs = ["203.0.113.10/32"]
  }
}

run "private_single_broker" {
  command = plan
  assert {
    condition = (
      aws_mq_broker.rabbitmq[0].publicly_accessible == false &&
      aws_mq_broker.rabbitmq[0].deployment_mode == "SINGLE_INSTANCE" &&
      length(aws_mq_broker.rabbitmq[0].subnet_ids) == 1 &&
      aws_mq_broker.rabbitmq[0].auto_minor_version_upgrade
    )
    error_message = "RabbitMQ must be a private single-instance managed broker with automatic minor upgrades."
  }
  assert {
    condition = (
      length(aws_lb_listener_rule.rabbitmq_allow) == 1 &&
      length(aws_lb_listener_rule.rabbitmq_deny) == 1 &&
      aws_lb_listener_rule.rabbitmq_allow[0].priority < aws_lb_listener_rule.rabbitmq_deny[0].priority &&
      aws_route53_record.rabbitmq[0].name == "rabbitmq.nomaos.com" &&
      aws_ecs_service.rabbitmq_proxy[0].network_configuration[0].assign_public_ip == false
    )
    error_message = "Management must use allowlisted ALB routing, a deny fallback, and a private proxy task."
  }
  assert {
    condition = (
      random_password.rabbitmq[0].length >= 32 &&
      aws_secretsmanager_secret.rabbitmq[0].recovery_window_in_days == 30
    )
    error_message = "Bootstrap credentials require a strong generated password and recoverable secret storage."
  }
}

run "empty_allowlist_is_closed" {
  command = plan
  variables {
    rabbitmq = { enabled = true, allowed_cidrs = [] }
  }
  assert {
    condition = (
      length(aws_lb_listener_rule.rabbitmq_allow) == 0 &&
      length(aws_ecs_service.rabbitmq_proxy) == 0 &&
      length(aws_lb_listener_rule.rabbitmq_deny) == 1
    )
    error_message = "An empty allowlist must not start an unreachable proxy service or permit management requests."
  }
}

run "disabled" {
  command = plan
  variables {
    rabbitmq = { enabled = false }
  }
  assert {
    condition = (
      length(aws_mq_broker.rabbitmq) == 0 &&
      length(aws_ecs_service.rabbitmq_proxy) == 0 &&
      length(aws_route53_record.rabbitmq) == 0
    )
    error_message = "Disabled RabbitMQ must not create a broker, proxy or DNS record."
  }
}
