# =============================================================================
# PROD — HashiCorp Vault (Fargate, raft on EFS, KMS auto-unseal)
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
  target = data.aws_region.current
  values = { name = "eu-west-1" }
}

override_data {
  target = data.aws_elb_service_account.main
  values = { id = "156460612806" }
}

variables {
  domain_name        = "nomaos.com"
  mssql_databases    = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]
  log_retention_days = 30

  services = {
    wallet = {
      image         = "ealen/echo-server:latest"
      port          = 5001
      cpu           = 256
      memory        = 512
      desired_count = 1
      subdomain     = "wallet-api"
    }
    onboarding = {
      image         = "ealen/echo-server:latest"
      port          = 5002
      cpu           = 256
      memory        = 512
      desired_count = 1
      subdomain     = "onboarding-api"
    }
    input = {
      image         = "ealen/echo-server:latest"
      port          = 5003
      cpu           = 256
      memory        = 512
      desired_count = 1
      subdomain     = "input-api"
    }
    moneval = {
      image         = "ealen/echo-server:latest"
      port          = 5004
      cpu           = 256
      memory        = 512
      desired_count = 1
      subdomain     = "moneval-api"
    }
    serviceprovider = {
      image         = "ealen/echo-server:latest"
      port          = 5005
      cpu           = 256
      memory        = 512
      desired_count = 1
      subdomain     = "serviceprovider-api"
    }
  }
}

# -----------------------------------------------------------------------------
# KMS (auto-unseal) + EFS (raft storage)
# -----------------------------------------------------------------------------

run "kms_and_efs" {
  command = plan

  assert {
    condition     = aws_kms_key.vault.enable_key_rotation == true
    error_message = "The Vault KMS key must rotate automatically."
  }

  assert {
    condition     = aws_kms_alias.vault[0].name == "alias/${var.project}-${var.environment}-vault"
    error_message = "KMS alias follows the naming convention."
  }

  assert {
    condition     = aws_efs_file_system.vault[0].encrypted == true
    error_message = "Vault raft storage must be encrypted."
  }

  assert {
    condition     = length(aws_efs_access_point.vault) == 1
    error_message = "Vault mounts EFS through an access point."
  }

  # Regression: this used to be count = length(aws_subnet.private), which is
  # unknown until apply ("Invalid count argument").
  assert {
    condition     = length(aws_efs_mount_target.vault) == 2
    error_message = "One mount target per private subnet; the count must be known at plan time."
  }
}

# -----------------------------------------------------------------------------
# Service + load balancing
# -----------------------------------------------------------------------------

run "service" {
  command = plan

  assert {
    condition     = aws_ecs_service.vault[0].launch_type == "FARGATE"
    error_message = "Vault runs on Fargate."
  }

  assert {
    condition     = aws_ecs_service.vault[0].desired_count == 1
    error_message = "A single raft node: never run two writers."
  }

  assert {
    condition     = one(aws_ecs_service.vault[0].deployment_circuit_breaker).rollback == true
    error_message = "A failed Vault deploy must roll back."
  }

  assert {
    condition     = [for lb in aws_ecs_service.vault[0].load_balancer : lb.container_port] == [8200]
    error_message = "The ALB targets Vault on 8200."
  }

  assert {
    condition     = aws_lb_target_group.vault[0].port == var.vault_port
    error_message = "Target group port follows var.vault_port."
  }

  assert {
    condition     = one(aws_lb_target_group.vault[0].health_check).matcher == "200-399"
    error_message = "Sealed/uninitialized Vault must still count as healthy (operator init happens later)."
  }

  assert {
    condition     = aws_lb_listener_rule.vault[0].priority == 10
    error_message = "Vault uses priority 10, clear of the service rules 1..N."
  }

  assert {
    condition = flatten([
      for c in aws_lb_listener_rule.vault[0].condition : [
        for h in c.host_header : h.values
      ]
    ]) == ["vault.nomaos.com"]
    error_message = "Vault is published at <vault_subdomain>.<domain>."
  }

  assert {
    condition     = aws_cloudwatch_log_group.vault[0].retention_in_days == 30
    error_message = "Vault log retention follows var.log_retention_days."
  }
}

# -----------------------------------------------------------------------------
# Everything disappears with enable_vault = false
# -----------------------------------------------------------------------------

run "vault_disabled" {
  command = plan

  variables {
    enable_vault = false
  }

  assert {
    condition     = length(aws_efs_mount_target.vault) == 0
    error_message = "enable_vault = false must remove the EFS mount targets."
  }

  assert {
    condition     = length(aws_ecs_service.vault) == 0
    error_message = "enable_vault = false must remove the Vault service."
  }

  assert {
    condition     = length(aws_lb_listener_rule.vault) == 0
    error_message = "enable_vault = false must remove the Vault listener rule."
  }

  assert {
    condition     = contains(keys(aws_route53_record.alias), "vault") == false
    error_message = "enable_vault = false must remove the vault DNS alias."
  }
}

# -----------------------------------------------------------------------------
# Vault also runs on Graviton, at the Fargate floor
# -----------------------------------------------------------------------------

run "vault_task_platform" {
  command = plan

  assert {
    condition     = [for p in aws_ecs_task_definition.vault[0].runtime_platform : p.cpu_architecture] == ["ARM64"]
    error_message = "The Vault task runs on Graviton too (hashicorp/vault ships a linux/arm64 image)."
  }

  assert {
    condition = (
      tonumber(aws_ecs_task_definition.vault[0].cpu) == 256 &&
      tonumber(aws_ecs_task_definition.vault[0].memory) == 512
    )
    error_message = "Vault runs at the Fargate floor (256 CPU / 512 MB); bump var.vault_cpu/memory if it OOMs."
  }
}
