# =============================================================================
# DEV — EC2 app host (nginx + docker compose: 7 APIs, Vault, SQL Server)
#
# Run with:  terraform -chdir=dev init && terraform -chdir=dev test
# =============================================================================

mock_provider "aws" {}

override_data {
  target = data.aws_availability_zones.available
  values = {
    names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  }
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:root"
  }
}

override_data {
  target = data.aws_ami.ubuntu
  values = {
    id = "ami-0123456789abcdef0"
  }
}

override_data {
  target = data.aws_iam_policy_document.ec2_assume
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.ec2
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.scheduler_assume
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"scheduler.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.scheduler
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

variables {
  vault              = { subdomain = "dev-vault", oidc_enabled = false }
  manage_fresh_vault = false
  import_existing = false

  ami_id            = "ami-0123456789abcdef0"
  domain_name       = "nomaos.com"
  mssql_sa_password = "Str0ng!TestOnly" # ggignore - test fixture, not a credential
  mssql_databases   = ["wallet", "onboarding", "input", "moneval", "serviceprovider", "nomaos"]
  instance_type     = "t3.large"

  apis = {
    nomaos = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5000
      subdomain = "dev-noma-api"
    }
    wallet = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5001
      subdomain = "dev-wallet-api"
    }
    onboarding = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5002
      subdomain = "dev-onboarding-api"
    }
    input = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5003
      subdomain = "dev-input-api"
    }
    moneval = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5004
      subdomain = "dev-moneval-api"
    }
    serviceprovider = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5005
      subdomain = "dev-serviceprovider-api"
    }
  }

  amplify_apps = {
    landing = {
      repository = "https://github.com/Agrovesto/nomaos-landingpage"
      branch     = "dev"
      subdomain  = "dev-agrovesto"
      framework  = "React"
    }
    onboarding = {
      repository = "https://github.com/Agrovesto/onboarding-frontend"
      branch     = "dev"
      subdomain  = "onboarding-dev"
      framework  = "React"
    }
  }
}

# -----------------------------------------------------------------------------
# Instance
# -----------------------------------------------------------------------------

run "instance" {
  command = plan

  assert {
    condition     = aws_instance.app.instance_type == "t3.large"
    error_message = "The dev host runs on t3.large (2 vCPU / 8 GiB), which is what the logging stack on it needs."
  }

  assert {
    condition     = aws_instance.app.associate_public_ip_address == false
    error_message = "Fresh hosts should use the Elastic IP rather than request an auto-assigned public IP."
  }

  assert {
    condition = (
      strcontains(file("${path.module}/ec2.tf"), "prevent_destroy = true") &&
      strcontains(file("${path.module}/ec2.tf"), "ignore_changes = [ami, user_data, associate_public_ip_address]")
    )
    error_message = "The already-running root-backed Vault host must not be replaced to change its legacy public-IP flag."
  }

  assert {
    condition     = [for m in aws_instance.app.metadata_options : m.http_tokens] == ["required"]
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = aws_instance.app.tags["Project"] == var.project && aws_instance.app.tags["Environment"] == var.environment
    error_message = "Every resource must carry the Project/Environment tags."
  }
}

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------

run "storage" {
  command = plan

  assert {
    condition     = [for b in aws_instance.app.root_block_device : b.volume_size] == [50]
    error_message = "Root volume is 50 GB."
  }

  assert {
    condition     = [for b in aws_instance.app.root_block_device : b.volume_type] == ["gp3"]
    error_message = "Root volume is gp3."
  }

  assert {
    condition     = [for b in aws_instance.app.root_block_device : b.encrypted] == [true]
    error_message = "The root volume must be encrypted."
  }

  assert {
    condition     = [for b in aws_instance.app.root_block_device : b.delete_on_termination] == [true]
    error_message = "The root volume follows the instance lifecycle."
  }

  assert {
    condition     = aws_ebs_volume.mssql.size == 50
    error_message = "SQL Server data volume is 50 GB."
  }

  assert {
    condition     = aws_ebs_volume.mssql.encrypted == true
    error_message = "The SQL Server data volume must be encrypted."
  }

  assert {
    condition     = aws_ebs_volume.mssql.type == "gp3"
    error_message = "The SQL Server data volume is gp3."
  }
}

# -----------------------------------------------------------------------------
# Elastic IP
# -----------------------------------------------------------------------------

run "elastic_ip" {
  command = plan

  assert {
    condition     = length(aws_eip.app) == 1
    error_message = "associate_elastic_ip = true attaches a stable Elastic IP for DNS."
  }

  assert {
    condition     = length(aws_eip_association.app) == 1
    error_message = "The Elastic IP must be associated with the instance."
  }
}

run "no_elastic_ip" {
  command = plan

  variables {
    associate_elastic_ip = false
  }

  assert {
    condition     = length(aws_eip.app) == 0
    error_message = "associate_elastic_ip = false must not allocate an Elastic IP."
  }
}

# -----------------------------------------------------------------------------
# SQL Server edition on the dev host
# -----------------------------------------------------------------------------

run "mssql_edition" {
  command = plan

  assert {
    condition     = strcontains(local.docker_compose, "MSSQL_PID: \"Developer\"")
    error_message = "dev runs SQL Server Developer Edition: free, full Enterprise feature set, dev/test use only."
  }
}

run "mssql_edition_overridable" {
  command = plan

  variables {
    mssql_pid = "Express"
  }

  assert {
    condition     = strcontains(local.docker_compose, "MSSQL_PID: \"Express\"")
    error_message = "var.mssql_pid must reach the compose file (set it to Express when dev must mirror prod's 10 GB cap)."
  }
}

# -----------------------------------------------------------------------------
# SNS topics + host alarms (sns.tf, alarms.tf)
# -----------------------------------------------------------------------------

run "sns_and_alarms" {
  command = plan

  variables {
    alert_emails     = ["ops@example.com"]
    app_sns_topics   = ["notifications"]
    app_topic_emails = ["dev@example.com"]
  }

  assert {
    condition     = aws_kms_key.sns.enable_key_rotation && aws_kms_alias.sns.name == "alias/${var.project}-${var.environment}-sns"
    error_message = "SNS topics use a rotating customer-managed key (alarms cannot publish to aws/sns)."
  }

  assert {
    condition     = aws_sns_topic.alerts.name == "${var.project}-${var.environment}-alerts"
    error_message = "Alerts topic follows the naming convention."
  }

  assert {
    condition     = aws_sns_topic_policy.alerts != null
    error_message = "The alerts topic has a policy letting CloudWatch publish."
  }

  assert {
    condition     = length(aws_sns_topic_subscription.alerts_email) == 1 && length(aws_sns_topic.app) == 1 && length(aws_sns_topic_subscription.app_email) == 1
    error_message = "Email subscriptions and app topics follow the variables."
  }

  assert {
    condition     = length(aws_iam_role_policy.ec2_sns) == 1
    error_message = "The host role may publish to the app topics."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ec2_status_check.treat_missing_data == "notBreaching" && aws_cloudwatch_metric_alarm.ec2_cpu.metric_name == "CPUUtilization"
    error_message = "Host alarms don't fire while the scheduler has the host stopped."
  }
}
