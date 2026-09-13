# =============================================================================
# PROD — ECR repositories + lifecycle policies
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
# Repositories
# -----------------------------------------------------------------------------

run "repositories" {
  command = plan

  assert {
    condition     = length(aws_ecr_repository.services) == 5
    error_message = "One repository per service."
  }

  assert {
    condition     = aws_ecr_repository.services["wallet"].name == "${var.project}-${var.environment}-wallet"
    error_message = "Repository names follow <project>-<environment>-<service>."
  }

  assert {
    condition     = aws_ecr_repository.services["wallet"].image_tag_mutability == "IMMUTABLE"
    error_message = "Prod tags must be immutable (release tags cannot be overwritten)."
  }

  assert {
    condition     = aws_ecr_repository.services["wallet"].force_delete == false
    error_message = "force_delete must stay false in prod so destroy cannot wipe images."
  }

  assert {
    condition     = aws_ecr_repository.services["wallet"].image_scanning_configuration[0].scan_on_push == true
    error_message = "Scan on push must stay enabled."
  }

  assert {
    condition     = aws_ecr_repository.services["wallet"].encryption_configuration[0].encryption_type == "KMS"
    error_message = "Repositories must be encrypted with KMS."
  }

  assert {
    condition     = length(aws_ecr_lifecycle_policy.services) == 5
    error_message = "Every repository needs a lifecycle policy."
  }
}

# -----------------------------------------------------------------------------
# Lifecycle policy contents
# -----------------------------------------------------------------------------

run "lifecycle_policy" {
  command = plan

  assert {
    condition     = jsondecode(aws_ecr_lifecycle_policy.services["wallet"].policy).rules[0].selection.countNumber == 14
    error_message = "Untagged images expire after 14 days."
  }

  assert {
    condition     = jsondecode(aws_ecr_lifecycle_policy.services["wallet"].policy).rules[1].selection.countNumber == var.ecr_images_to_keep
    error_message = "Tagged image retention must follow var.ecr_images_to_keep."
  }

  assert {
    condition     = jsondecode(aws_ecr_lifecycle_policy.services["wallet"].policy).rules[0].action.type == "expire"
    error_message = "Both rules expire images."
  }
}
