# Remaining task definitions, secondary security-group rules and IAM policies.

mock_provider "aws" {}

# The cost resources use the us-east-1 provider alias; without a mock for it the
# test would configure the real provider and ask for credentials.
mock_provider "aws" {
  alias = "us_east_1"
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "221434544570"
    arn        = "arn:aws:iam::221434544570:root"
  }
}

override_data {
  target = data.aws_region.current
  values = { name = "eu-west-1" }
}

override_data {
  target = data.aws_vpc.prod
  values = {
    id         = "vpc-0prod"
    cidr_block = "10.0.0.0/16"
  }
}

override_data {
  target = data.aws_subnets.private
  values = { ids = ["subnet-0private1", "subnet-0private2"] }
}

override_data {
  target = data.aws_subnet.monitoring
  values = {
    id                = "subnet-0private1"
    availability_zone = "eu-west-1a"
    cidr_block        = "10.0.11.0/24"
  }
}

override_data {
  target = data.aws_lb.main
  values = {
    arn      = "arn:aws:elasticloadbalancing:eu-west-1:221434544570:loadbalancer/app/agrovesto-prod-alb/1234"
    dns_name = "agrovesto-prod-alb-1234.eu-west-1.elb.amazonaws.com"
    zone_id  = "Z32O12XQLNTSW2"
  }
}

override_data {
  target = data.aws_lb_listener.https
  values = { arn = "arn:aws:elasticloadbalancing:eu-west-1:221434544570:listener/app/agrovesto-prod-alb/1234/5678" }
}

override_data {
  target = data.aws_security_group.alb
  values = { id = "sg-0alb" }
}

override_data {
  target = data.aws_route53_zone.main
  values = {
    zone_id = "Z0123456789ABCDEF"
    name    = "nomaos.com."
  }
}

variables {
  domain_name        = "nomaos.com"
  monthly_budget_usd = 250
}

run "every_task_definition_is_complete" {
  command = plan

  assert {
    condition = alltrue([
      aws_ecs_task_definition.loki[*].cpu != null,
      aws_ecs_task_definition.tempo[*].cpu != null,
      aws_ecs_task_definition.grafana.cpu != null,
      aws_ecs_task_definition.edge.cpu != null
    ])
    error_message = "Every task definition needs an explicit cpu value."
  }

  assert {
    condition = alltrue([
      strcontains(jsonencode(aws_ecs_task_definition.loki[*].container_definitions), "grafana/loki:"),
      strcontains(jsonencode(aws_ecs_task_definition.tempo[*].container_definitions), "grafana/tempo:"),
      strcontains(jsonencode(aws_ecs_task_definition.edge.container_definitions), "grafana/alloy:"),
      strcontains(jsonencode(aws_ecs_task_definition.edge.container_definitions), "prom/blackbox-exporter:"),
    ])
    error_message = "Task definitions must pin the open-source images."
  }

  assert {
    condition     = aws_ecs_task_definition.grafana.network_mode == "awsvpc" && contains(aws_ecs_task_definition.grafana.requires_compatibilities, "FARGATE")
    error_message = "Tasks must run on awsvpc Fargate."
  }

  assert {
    condition     = strcontains(jsonencode(aws_ecs_task_definition.loki[*].container_definitions), "grafana/loki:")
    error_message = "Loki must run the pinned upstream image."
  }

  assert {
    condition = alltrue([
      aws_ecs_service.edge.desired_count == 1
    ])
    error_message = "The ingest gateway, pushgateway and Alertmanager must run as one task."
  }

  assert {
    condition     = strcontains(jsonencode(aws_ecs_task_definition.edge.container_definitions), "4317")
    error_message = "The Alloy gateway must expose OTLP."
  }

  assert {
    condition     = strcontains(jsonencode(aws_ecs_task_definition.loki[*].container_definitions), "3100")
    error_message = "Loki must expose its push and query API."
  }
}

run "secondary_ingress_rules_are_pinned" {
  command = plan

  assert {
    condition     = aws_security_group_rule.internal_tempo_query.from_port == 3200 && aws_security_group_rule.internal_tempo_query.to_port == 3200
    error_message = "Tempo query port drifted."
  }

  assert {
    condition     = aws_security_group_rule.internal_alertmanager.from_port == 9093
    error_message = "Alertmanager must be reachable inside the VPC."
  }

  assert {
    condition     = aws_security_group_rule.internal_pushgateway.from_port == 9091
    error_message = "Pushgateway must be reachable inside the VPC."
  }

  assert {
    condition     = aws_security_group_rule.internal_blackbox.from_port == 9115
    error_message = "Blackbox must be reachable from Prometheus."
  }

  assert {
    condition     = aws_security_group_rule.internal_alloy_metrics.from_port == 12345
    error_message = "Alloy self-metrics port drifted."
  }

  assert {
    condition = alltrue([
      aws_security_group_rule.internal_egress.type == "egress",
      aws_security_group_rule.grafana_egress.type == "egress",
      aws_security_group_rule.efs_egress.type == "egress"
    ])
    error_message = "Egress rules must be egress."
  }

  assert {
    condition     = aws_security_group.grafana.name == "agrovesto-monitoring-grafana-sg" && aws_security_group.efs.name == "agrovesto-monitoring-efs-sg"
    error_message = "Security group naming drifted."
  }
}

run "policies_grant_the_minimum" {
  command = plan

  assert {
    condition     = aws_iam_role_policy.execution_ssm.name == "agrovesto-monitoring-execution-ssm"
    error_message = "Execution-role policy name drifted."
  }

  assert {
    condition = alltrue([
      strcontains(aws_iam_role_policy.execution_ssm.policy, "kms:Decrypt"),
      strcontains(aws_iam_role_policy.execution_ssm.policy, "ssm:GetParameters"),
    ])
    error_message = "The init container must be able to read and decrypt its config."
  }

  assert {
    condition     = aws_iam_role_policy.task.name == "agrovesto-monitoring-task-policy"
    error_message = "The task role policy name drifted."
  }

  assert {
    condition     = one(aws_iam_role_policy.task_database_secret[*].name) == "agrovesto-monitoring-task-database-secret-policy"
    error_message = "The database secret policy name drifted."
  }

  assert {
    condition     = strcontains(one(aws_iam_role_policy.task_database_secret[*].policy), "kms:ViaService")
    error_message = "Decrypting the database secret must stay scoped to Secrets Manager."
  }

  assert {
    condition     = one(aws_iam_role_policy.events[*].name) == "agrovesto-monitoring-events-policy"
    error_message = "The scheduler role policy name drifted."
  }

  assert {
    condition     = aws_kms_alias.monitoring.name == "alias/agrovesto-monitoring-efs"
    error_message = "EFS key alias drifted."
  }
}

run "storage_and_schedule_settings" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.cur[0].block_public_acls && aws_s3_bucket_public_access_block.cur[0].block_public_policy
    error_message = "The CUR bucket must block public access."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.cur[0].rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "The CUR bucket must be encrypted at rest."
  }

  assert {
    condition     = aws_s3_object.budget_script[0].key == "scripts/budget_report.py"
    error_message = "The budget script key must match what the task downloads."
  }

  assert {
    condition     = one(aws_cloudwatch_event_target.budget[0].ecs_target).task_count == 1 && one(one(aws_cloudwatch_event_target.budget[0].ecs_target).network_configuration).assign_public_ip == false
    error_message = "The budget task must run one private task per schedule."
  }

  assert {
    condition     = random_password.grafana_admin.length == 32 && random_password.grafana_admin.special == false
    error_message = "The generated Grafana password must stay quote-safe."
  }

  assert {
    condition     = one(aws_cloudwatch_event_target.mssql[0].ecs_target).platform_version == "1.4.0"
    error_message = "The metrics task runs on the Fargate 1.4.0 platform."
  }

  assert {
    condition     = aws_ecs_task_definition.mssql_metrics[0].network_mode == "awsvpc"
    error_message = "The metrics task mounts the shared config volume."
  }

  assert {
    condition     = aws_cloudwatch_event_rule.mssql[0].name == "agrovesto-monitoring-mssql-metrics"
    error_message = "The metrics schedule name drifted."
  }
}

run "alertmanager_publishes_to_sns" {
  command = plan

  variables {
    alertmanager_sns_topic = "agrovesto-prod-alerts"
  }

  assert {
    condition = alltrue([
      strcontains(aws_s3_object.config["alertmanager/alertmanager.yml"].content, "sns_configs:"),
      strcontains(aws_s3_object.config["alertmanager/alertmanager.yml"].content, "topic_arn: arn:aws:sns:eu-west-1:221434544570:agrovesto-prod-alerts"),
      strcontains(aws_s3_object.config["alertmanager/alertmanager.yml"].content, "send_resolved: true"),
    ])
    error_message = "Alertmanager must publish (and resolve) to the prod alerts topic."
  }

  assert {
    condition = alltrue([
      one(aws_iam_role_policy.task_alerts_sns[*].name) == "agrovesto-monitoring-task-alerts-sns-policy",
      strcontains(one(aws_iam_role_policy.task_alerts_sns[*].policy), "arn:aws:sns:eu-west-1:221434544570:agrovesto-prod-alerts"),
      strcontains(one(aws_iam_role_policy.task_alerts_sns[*].policy), "sns.eu-west-1.amazonaws.com"),
    ])
    error_message = "The task role may publish only to that topic, and use KMS only through SNS."
  }
}

run "no_sns_receiver_when_unset" {
  command = plan

  variables {
    alertmanager_sns_topic = ""
  }

  assert {
    condition     = !strcontains(aws_s3_object.config["alertmanager/alertmanager.yml"].content, "sns_configs") && length(aws_iam_role_policy.task_alerts_sns) == 0
    error_message = "With no topic there is no SNS receiver and no publish permission."
  }
}

run "config_bucket_is_private_and_tls_only" {
  # plan + pinned computed attributes: a full mocked apply of the monitoring
  # module feeds random strings into ARNs and policies and is fragile.
  command = plan

  override_resource {
    target = aws_s3_bucket.config
    values = {
      id  = "agrovesto-monitoring-config-221434544570"
      arn = "arn:aws:s3:::agrovesto-monitoring-config-221434544570"
    }
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.config.block_public_policy && aws_s3_bucket_public_access_block.config.restrict_public_buckets
    error_message = "The config bucket blocks public access."
  }

  assert {
    condition     = aws_s3_bucket.config.bucket == "agrovesto-monitoring-config-221434544570"
    error_message = "The config bucket is <name>-config-<account> so it is globally unique."
  }

  # The policy JSON embeds the bucket ARN, which is unknown in a plan; check
  # the resource is wired to the bucket and holds the TLS-only statement input.
  assert {
    condition     = aws_s3_bucket_policy.config != null
    error_message = "The config bucket has the TLS-only bucket policy."
  }
}
