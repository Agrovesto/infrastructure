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
  ui_https_enabled   = false
  vault              = { subdomain = "dev-vault", oidc_enabled = false }
  manage_fresh_vault = false
  import_existing    = false

  ami_id            = "ami-0123456789abcdef0"
  domain_name       = "nomaos.com"
  mssql_sa_password = "Str0ng!TestOnly" # ggignore - test fixture, not a credential
  mssql_databases   = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]
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


# Plan-only: protected resources cannot be mock-applied and then destroyed by
# test teardown. Computed-ID wiring is checked against source; resource settings
# are asserted against the actual plan. tests/test_ssm_shell.py exercises the
# real Bash wrapper under /bin/sh without requiring an AWS apply.
run "managed_fresh_vault" {
  command = plan
  assert {
    condition = (
      strcontains(file("${path.module}/ec2.tf"), "bash <<'AGROVESTO_HOST_REFRESH_BASH'") &&
      strcontains(file("${path.module}/ec2.tf"), "[\"AGROVESTO_HOST_REFRESH_BASH\"]")
    )
    error_message = "SSM must explicitly run Bash rather than pass pipefail to /bin/sh."
  }
  variables {
    manage_fresh_vault            = true
    prepare_vault_kms_auto_unseal = true
  }
  assert {
    condition     = aws_ebs_volume.vault[0].encrypted && aws_ebs_volume.vault[0].size == 20
    error_message = "Vault needs a dedicated encrypted volume."
  }
  assert {
    condition = (
      aws_volume_attachment.vault[0].device_name == "/dev/sdi" &&
      aws_volume_attachment.vault[0].stop_instance_before_detaching &&
      can(regex("volume_id\\s*=\\s*aws_ebs_volume\\.vault\\[0\\]\\.id", file("${path.module}/vault_storage.tf")))
    )
    error_message = "Vault attachment must use the dedicated volume."
  }
  assert {
    condition = (
      contains(keys(aws_s3_object.host_config), "vault/managed-vault.hcl") &&
      aws_kms_key.vault_unseal[0].enable_key_rotation &&
      strcontains(file("${path.module}/locals.tf"), "kms_key_id = \"$${aws_kms_key.vault_unseal[0].arn}\"")
    )
    error_message = "Vault config must use the managed KMS key, not a literal ARN."
  }
  assert {
    condition = (
      contains(keys(aws_s3_object.host_config), "scripts/prepare-vault.sh") &&
      strcontains(file("${path.module}/locals.tf"), "volume_serial = replace(aws_ebs_volume.vault[0].id, \"-\", \"\")")
    )
    error_message = "Device resolution must use the exact EBS serial."
  }
  assert {
    condition = (
      aws_dlm_lifecycle_policy.vault[0].state == "ENABLED" &&
      aws_iam_role.vault_snapshots[0].name == "${var.project}-${var.environment}-vault-snapshots" &&
      aws_iam_role_policy_attachment.vault_snapshots[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
    )
    error_message = "Vault snapshot schedule must be enabled."
  }
}

run "vault_provider_constraints" {
  command = plan
  variables {
    manage_fresh_vault            = true
    prepare_vault_kms_auto_unseal = true
  }
  assert {
    condition     = aws_ssm_association.host_config_refresh.wait_for_success_timeout_seconds == 900
    error_message = "SSM association timeout must use provider-supported seconds."
  }
  assert {
    condition     = can(regex("^[0-9A-Za-z _-]+$", aws_dlm_lifecycle_policy.vault[0].description))
    error_message = "DLM descriptions may contain only alphanumerics, spaces, underscores and hyphens."
  }
}
