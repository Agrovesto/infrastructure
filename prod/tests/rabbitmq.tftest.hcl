mock_provider "aws" {}
mock_provider "random" {}

override_resource {
  target = aws_security_group.rabbitmq_clients[0]
  values = { id = "sg-0123456789abcdef0" }
}

# Pin the shared ECS SG too, so the security-group list in the service local
# is fully known during this plan-only test.
override_resource {
  target = aws_security_group.ecs
  values = { id = "sg-0123456789abcdef1" }
}

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
    enabled = true
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
      length(aws_security_group.rabbitmq[0].ingress) == 2 &&
      alltrue([for rule in aws_security_group.rabbitmq[0].ingress :
        length(rule.cidr_blocks) == 0 &&
        length(rule.ipv6_cidr_blocks) == 0 &&
        rule.security_groups == toset([aws_security_group.rabbitmq_clients[0].id]) &&
        contains([443, 5671], rule.from_port) && rule.from_port == rule.to_port
      ])
    )
    error_message = "RabbitMQ ingress must allow only TCP 443 and 5671 from the client security group, with no CIDR sources."
  }
  assert {
    condition = alltrue([
      for service_name in keys(var.services) : contains(
        local.ecs_service_security_groups[service_name],
        aws_security_group.rabbitmq_clients[0].id
      )
    ])
    error_message = "Every application ECS service must attach the dedicated RabbitMQ client security group."
  }
  assert {
    condition = (
      random_password.rabbitmq[0].length >= 32 &&
      aws_secretsmanager_secret.rabbitmq[0].recovery_window_in_days == 30
    )
    error_message = "Bootstrap credentials require a strong generated password and recoverable secret storage."
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
      length(aws_security_group.rabbitmq_clients) == 0
    )
    error_message = "Disabled RabbitMQ must not create a broker or client security group."
  }
}
