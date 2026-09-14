# =============================================================================
# PROD — Security groups
#
#   Internet -> ALB SG (80/443) -> ECS SG (service ports, ALB only) -> RDS SG
#   Vault's EFS mount targets accept NFS from the ECS SG only.
#
# NOTE: ingress/egress on aws_security_group are sets, so every assertion
# iterates instead of indexing.
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
  domain_name     = "nomaos.com"
  mssql_databases = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]

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
# ALB
# -----------------------------------------------------------------------------

run "alb_security_group" {
  command = plan

  assert {
    condition     = toset([for i in aws_security_group.alb.ingress : tonumber(i.from_port)]) == toset([80, 443])
    error_message = "The ALB accepts 80 and 443 from the internet."
  }

  assert {
    condition     = alltrue([for i in aws_security_group.alb.ingress : i.protocol == "tcp"])
    error_message = "ALB ingress is TCP only."
  }

  assert {
    condition     = toset(flatten([for i in aws_security_group.alb.ingress : i.cidr_blocks])) == toset(["0.0.0.0/0"])
    error_message = "HTTP/HTTPS must be reachable from anywhere."
  }
}

# -----------------------------------------------------------------------------
# ECS tasks
# -----------------------------------------------------------------------------

run "ecs_security_group" {
  command = plan

  assert {
    condition     = [for e in aws_security_group.ecs.egress : e.protocol] == ["-1"]
    error_message = "Tasks need unrestricted outbound (ECR, CloudWatch, Secrets Manager, RDS)."
  }

  assert {
    condition     = flatten([for e in aws_security_group.ecs.egress : e.cidr_blocks]) == ["0.0.0.0/0"]
    error_message = "ECS egress is unrestricted by design."
  }
}

# -----------------------------------------------------------------------------
# ALB <-> ECS: one rule per distinct service port
# -----------------------------------------------------------------------------

run "service_port_rules" {
  command = plan

  assert {
    condition = toset(keys(aws_security_group_rule.alb_to_ecs)) == toset([
      "5001", "5002", "5003", "5004", "5005", "8200"
    ])
    error_message = "One ALB->ECS egress rule per distinct port in local.service_ports (services + Vault)."
  }

  assert {
    condition = toset(keys(aws_security_group_rule.ecs_from_alb)) == toset([
      "5001", "5002", "5003", "5004", "5005", "8200"
    ])
    error_message = "One ECS<-ALB ingress rule per distinct port in local.service_ports."
  }

  assert {
    condition     = aws_security_group_rule.alb_to_ecs["8200"].type == "egress"
    error_message = "alb_to_ecs rules are egress rules on the ALB security group."
  }

  assert {
    condition     = aws_security_group_rule.ecs_from_alb["5001"].type == "ingress"
    error_message = "ecs_from_alb rules are ingress rules on the ECS security group."
  }

  assert {
    condition = (
      tonumber(aws_security_group_rule.ecs_from_alb["5001"].from_port) == 5001 &&
      tonumber(aws_security_group_rule.ecs_from_alb["5001"].to_port) == 5001 &&
      aws_security_group_rule.ecs_from_alb["5001"].protocol == "tcp"
    )
    error_message = "Each rule opens exactly one TCP port."
  }
}

run "service_port_rules_without_vault" {
  command = plan

  variables {
    enable_vault = false
  }

  assert {
    condition = toset(keys(aws_security_group_rule.ecs_from_alb)) == toset([
      "5001", "5002", "5003", "5004", "5005"
    ])
    error_message = "Vault's 8200 must drop out of the port rules when enable_vault = false."
  }
}

# -----------------------------------------------------------------------------
# RDS + EFS
# -----------------------------------------------------------------------------

run "database_and_efs_security_groups" {
  command = plan

  assert {
    condition     = [for i in aws_security_group.rds.ingress : i.from_port] == [1433]
    error_message = "SQL Server accepts 1433 only."
  }

  assert {
    condition     = [for i in aws_security_group.rds.ingress : i.protocol] == ["tcp"]
    error_message = "RDS ingress is TCP only."
  }

  assert {
    condition     = [for i in aws_security_group.efs[0].ingress : i.from_port] == [2049]
    error_message = "EFS accepts NFS (2049) from the ECS tasks."
  }
}

run "efs_security_group_without_vault" {
  command = plan

  variables {
    enable_vault = false
  }

  assert {
    condition     = length(aws_security_group.efs) == 0
    error_message = "enable_vault = false must not create the EFS security group."
  }
}
