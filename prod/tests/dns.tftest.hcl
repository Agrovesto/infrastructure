# =============================================================================
# PROD — Route 53 zones and every record type
#
# The prod account owns DNS for the root domain: it creates the zone for
# nomaos.com (imported), the agrovesto.com zone, the service aliases, and the
# dev records supplied through var.extra_*.
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
# Hosted zones
# -----------------------------------------------------------------------------

run "hosted_zones" {
  command = plan

  assert {
    condition     = length(aws_route53_zone.this) == 1
    error_message = "create_hosted_zone = true must create the zone for var.domain_name."
  }

  assert {
    condition     = aws_route53_zone.this[0].name == "nomaos.com"
    error_message = "The zone name must follow var.domain_name."
  }

  assert {
    condition     = aws_route53_zone.agrovesto.name == "agrovesto.com"
    error_message = "The legacy agrovesto.com zone is managed here too."
  }
}

run "existing_zone_mode" {
  command = plan

  variables {
    create_hosted_zone = false
    existing_zone_id   = "Z0000000000000000000A"
  }

  assert {
    condition     = length(aws_route53_zone.this) == 0
    error_message = "create_hosted_zone = false must not create a zone."
  }
}

# -----------------------------------------------------------------------------
# Service aliases -> ALB
# -----------------------------------------------------------------------------

run "service_alias_records" {
  command = plan

  assert {
    condition     = length(aws_route53_record.alias) == 6
    error_message = "Five services plus Vault must be aliased to the ALB."
  }

  assert {
    condition = sort(keys(aws_route53_record.alias)) == [
      "input-api",
      "moneval-api",
      "onboarding-api",
      "serviceprovider-api",
      "vault",
      "wallet-api",
    ]
    error_message = "Alias record keys are the service subdomains plus vault."
  }

  assert {
    condition     = aws_route53_record.alias["wallet-api"].type == "A"
    error_message = "Service records are alias A records."
  }

  assert {
    condition     = aws_route53_record.alias["wallet-api"].alias[0].evaluate_target_health == true
    error_message = "Service aliases evaluate target health."
  }
}

# -----------------------------------------------------------------------------
# Extra records (dev hosts live in this zone)
# -----------------------------------------------------------------------------

run "no_extra_records_by_default" {
  command = plan

  assert {
    condition     = length(aws_route53_record.a) == 0
    error_message = "No plain A records unless var.extra_a_records supplies them."
  }

  assert {
    condition     = length(aws_route53_record.cname) == 0
    error_message = "No CNAME records unless var.extra_cname_records supplies them."
  }
}

run "extra_records" {
  command = plan

  variables {
    extra_a_records = {
      "dev-wallet-api" = "203.0.113.10"
    }

    extra_cname_records = {
      "landing.dev" = "dev.example.amplifyapp.com"
    }
  }

  assert {
    condition     = length(aws_route53_record.a) == 1
    error_message = "One A record per entry in var.extra_a_records."
  }

  assert {
    condition     = aws_route53_record.a["dev-wallet-api"].name == "dev-wallet-api.nomaos.com"
    error_message = "Record names are <key>.<domain>."
  }

  assert {
    condition     = aws_route53_record.a["dev-wallet-api"].records == ["203.0.113.10"]
    error_message = "A records point at the supplied IPv4 address."
  }

  assert {
    condition     = aws_route53_record.a["dev-wallet-api"].ttl == var.dns_ttl
    error_message = "TTL follows var.dns_ttl."
  }

  assert {
    condition     = aws_route53_record.cname["landing.dev"].type == "CNAME"
    error_message = "CNAME records are created from var.extra_cname_records."
  }
}

run "apex_record_uses_the_bare_domain" {
  command = plan

  variables {
    extra_a_records = {
      "@" = "203.0.113.10"
    }
  }

  assert {
    condition     = aws_route53_record.a["@"].name == "nomaos.com"
    error_message = "The '@' key must render the bare domain, not '@.nomaos.com'."
  }
}
