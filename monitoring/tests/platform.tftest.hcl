# Network discovery, storage, IAM, security groups, Cloud Map and config delivery.

mock_provider "aws" {}

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
  values = {
    ids = ["subnet-0private1", "subnet-0private2"]
  }
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
  values = {
    arn = "arn:aws:elasticloadbalancing:eu-west-1:221434544570:listener/app/agrovesto-prod-alb/1234/5678"
  }
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

run "discovers_the_prod_network" {
  command = plan

  assert {
    condition     = local.monitor_subnet_id == "subnet-0private1"
    error_message = "The monitoring tasks must pin the first private subnet."
  }

  assert {
    condition     = aws_efs_file_system.monitoring.availability_zone_name == "eu-west-1a"
    error_message = "EFS One Zone must live in the AZ the tasks run in."
  }
}

run "storage_is_encrypted_and_shared" {
  command = plan

  assert {
    condition     = aws_efs_file_system.monitoring.encrypted && aws_efs_file_system.monitoring.throughput_mode == "elastic"
    error_message = "EFS must be encrypted and use elastic throughput."
  }

  assert {
    condition     = aws_kms_key.monitoring.enable_key_rotation
    error_message = "The EFS CMK must rotate."
  }

  assert {
    condition     = aws_efs_mount_target.monitoring.subnet_id == "subnet-0private1"
    error_message = "The single mount target must be in the monitoring subnet."
  }

  assert {
    condition     = length(aws_efs_access_point.monitoring) == 9
    error_message = "Every component that reads or writes shared state needs its own access point."
  }

  assert {
    condition     = one(aws_efs_access_point.monitoring["grafana"].posix_user).uid == 472
    error_message = "The Grafana access point must match the grafana user."
  }

  assert {
    condition     = one(aws_efs_access_point.monitoring["prometheus"].root_directory).path == "/prometheus"
    error_message = "Access points must be rooted at the component directory."
  }
}

run "security_groups_only_open_what_is_needed" {
  command = plan

  assert {
    condition     = aws_security_group.internal.name == "agrovesto-monitoring-internal-sg"
    error_message = "Internal security group name drifted."
  }

  assert {
    condition     = aws_security_group_rule.internal_prometheus.cidr_blocks == ["10.0.0.0/16"]
    error_message = "Prometheus must only accept traffic from the VPC."
  }

  assert {
    condition     = aws_security_group_rule.grafana_alb.source_security_group_id == "sg-0alb"
    error_message = "Grafana must only accept traffic from the prod ALB."
  }

  assert {
    condition     = aws_security_group_rule.efs_internal.type == "ingress" && aws_security_group_rule.efs_internal.from_port == 2049
    error_message = "EFS must accept NFS from the monitoring tasks."
  }

  assert {
    condition     = aws_security_group_rule.efs_grafana.from_port == 2049
    error_message = "Grafana mounts EFS over NFS."
  }

  assert {
    condition = alltrue([
      aws_security_group_rule.efs_tls_internal.from_port == 2996,
      aws_security_group_rule.efs_tls_grafana.from_port == 2996
    ])
    error_message = "The task definitions mount EFS with transit encryption, which needs the stunnel port open."
  }

  assert {
    condition     = aws_security_group_rule.internal_otlp.from_port == 4317 && aws_security_group_rule.internal_otlp.to_port == 4318
    error_message = "OTLP gRPC and HTTP ports must both be reachable."
  }

  assert {
    condition     = aws_security_group_rule.internal_loki.from_port == 3100
    error_message = "Loki push API port must be reachable."
  }
}

run "iam_is_scoped" {
  command = plan

  assert {
    condition     = aws_iam_role.execution.name == "agrovesto-monitoring-execution-role"
    error_message = "Execution role name drifted."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.execution.policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    error_message = "The execution role needs the managed ECS policy for ECR and logs."
  }

  assert {
    condition     = aws_iam_role.task.name == "agrovesto-monitoring-task-role"
    error_message = "Task role name drifted."
  }

  assert {
    condition     = aws_iam_role.events[0].name == "agrovesto-monitoring-events-role"
    error_message = "The scheduler role must exist when cost monitoring is on."
  }
}

run "cloud_map_publishes_component_endpoints" {
  command = plan

  assert {
    condition     = aws_service_discovery_private_dns_namespace.monitoring.name == "monitoring.internal"
    error_message = "Internal DNS namespace drifted."
  }

  assert {
    condition     = length(aws_service_discovery_service.monitoring) == 8
    error_message = "Every component needs a discovery service."
  }

  assert {
    condition     = one(one(aws_service_discovery_service.monitoring["prometheus"].dns_config).dns_records).type == "A"
    error_message = "Discovery records must be A records."
  }

  assert {
    condition     = one(one(aws_service_discovery_service.monitoring["alloy"].dns_config).dns_records).ttl == 10
    error_message = "Discovery TTL drifted."
  }

  assert {
    condition     = aws_ecs_cluster.monitoring.setting[0].value == "disabled"
    error_message = "Container Insights must stay off: this stack replaces it."
  }

  assert {
    condition     = aws_cloudwatch_log_group.monitoring.retention_in_days == 30
    error_message = "Component logs keep 30 days."
  }
}

run "config_is_published_for_the_init_container" {
  command = plan

  assert {
    condition     = length(aws_s3_object.config) == 20
    error_message = "Every config file, rule file, script and dashboard must be published for the init container."
  }

  assert {
    condition     = aws_s3_object.config["prometheus/prometheus.yml"].key == "config/prometheus/prometheus.yml" && aws_s3_object.config["prometheus/prometheus.yml"].bucket == aws_s3_bucket.config.id
    error_message = "Config objects must keep the component/relative-path layout."
  }

  assert {
    condition     = aws_s3_object.config["grafana/dashboards/services.json"].content_type == "application/json"
    error_message = "Dashboards must be published as JSON."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.config.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "The config bucket must use the stack CMK."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.config.block_public_acls && aws_s3_bucket_public_access_block.config.restrict_public_buckets
    error_message = "The config bucket must stay private."
  }

  assert {
    condition     = one(aws_s3_bucket_versioning.config.versioning_configuration).status == "Enabled"
    error_message = "Config objects must be versioned so a rollback is possible."
  }

  assert {
    condition     = one(one(aws_s3_bucket_lifecycle_configuration.config.rule).noncurrent_version_expiration).noncurrent_days == 7
    error_message = "Superseded config versions must expire to keep the bucket free."
  }

  assert {
    condition     = strcontains(aws_s3_bucket_policy.config.policy, "DenyNonTls")
    error_message = "The config bucket must refuse plain HTTP."
  }

  assert {
    condition     = aws_ssm_parameter.grafana_admin_password.type == "SecureString" && aws_ssm_parameter.grafana_admin_password.key_id == "alias/agrovesto-monitoring-efs"
    error_message = "The generated Grafana password must be a CMK-encrypted SecureString."
  }

  assert {
    condition     = strcontains(local.prometheus_config, "blackbox.monitoring.internal:9115")
    error_message = "Probes must be routed through the blackbox exporter."
  }

  assert {
    condition     = strcontains(local.prometheus_config, "wallet.nomaos.com")
    error_message = "Default probes must cover the prod services."
  }

  assert {
    condition     = strcontains(local.alertmanager_config, "receivers:")
    error_message = "Alertmanager must always have a receivers block."
  }

  assert {
    condition     = strcontains(local.prometheus_rds_rules, "mssql_up") && strcontains(local.prometheus_rds_rules, "MssqlDeadlockSpike") && strcontains(local.prometheus_rds_rules, "MssqlDatabaseNearSizeLimit")
    error_message = "The database rules must cover reachability and deadlocks."
  }
}
