# =============================================================================
# PROD — ACM wildcard certificate + DNS validation records
#
# The validation records are the regression cover for the "Invalid for_each"
# bug: aws_acm_certificate is created in the same apply, so every one of its
# attributes is "known only after apply". for_each keys must come from
# local.acm_domains (variables), never from the certificate.
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
  rabbitmq        = { enabled = false }
  import_existing = false

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
# Certificate
# -----------------------------------------------------------------------------

run "certificate" {
  command = plan

  assert {
    condition     = aws_acm_certificate.wildcard.domain_name == "*.nomaos.com"
    error_message = "CN must be the wildcard *.<domain> so every service subdomain is covered."
  }

  assert {
    condition     = toset(aws_acm_certificate.wildcard.subject_alternative_names) == toset(["nomaos.com"])
    error_message = "The apex must stay on the certificate as a SAN (the wildcard does not cover it)."
  }

  assert {
    condition     = aws_acm_certificate.wildcard.validation_method == "DNS"
    error_message = "DNS validation is required (the zone is managed here)."
  }
}

# -----------------------------------------------------------------------------
# Validation records — the for_each regression
# -----------------------------------------------------------------------------

run "validation_records" {
  command = plan

  assert {
    condition     = toset(keys(aws_route53_record.acm_validation)) == toset(["*.nomaos.com", "nomaos.com"])
    error_message = "Exactly one validation record per entry in local.acm_domains, keyed by domain."
  }

  assert {
    condition     = aws_route53_record.acm_validation["nomaos.com"].allow_overwrite == true
    error_message = "allow_overwrite must stay true: ACM returns the SAME CNAME for the apex and the wildcard."
  }

  assert {
    condition     = aws_route53_record.acm_validation["nomaos.com"].ttl == 60
    error_message = "Validation records use a 60s TTL."
  }

  assert {
    condition     = aws_route53_record.acm_validation["nomaos.com"].type == "CNAME"
    error_message = "ACM DNS validation records are CNAMEs."
  }
}

run "validation_records_follow_the_domain_variable" {
  command = plan

  variables {
    domain_name = "example.com"
  }

  assert {
    condition     = toset(keys(aws_route53_record.acm_validation)) == toset(["*.example.com", "example.com"])
    error_message = "Certificate and validation records must both follow var.domain_name (single source of truth)."
  }

  assert {
    condition     = aws_acm_certificate.wildcard.domain_name == "*.example.com"
    error_message = "Certificate CN must follow var.domain_name."
  }
}
