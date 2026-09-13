# =============================================================================
# PROD — VPC, subnets, routing, NAT, flow logs
#
# Run with:  terraform -chdir=prod init && terraform -chdir=prod test
#
# Uses mock_provider: no AWS credentials, no API calls, no state.
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
# VPC
# -----------------------------------------------------------------------------

run "vpc" {
  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == var.vpc_cidr
    error_message = "VPC CIDR must come from var.vpc_cidr."
  }

  assert {
    condition     = aws_vpc.main.enable_dns_support && aws_vpc.main.enable_dns_hostnames
    error_message = "DNS support + hostnames are required (RDS endpoint, ECS service discovery)."
  }

  assert {
    condition     = aws_vpc.main.tags["Project"] == var.project && aws_vpc.main.tags["Environment"] == var.environment
    error_message = "Every resource must carry the Project/Environment tags."
  }
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

run "subnets" {
  command = plan

  assert {
    condition = (
      length(aws_subnet.public) == 2 &&
      length(aws_subnet.private) == 2 &&
      length(aws_subnet.database) == 2
    )
    error_message = "Expected 2 public, 2 private and 2 database subnets."
  }

  assert {
    condition     = [for s in aws_subnet.private : s.map_public_ip_on_launch] == [false, false]
    error_message = "Private subnets must never auto-assign public IPs."
  }

  assert {
    condition     = [for s in aws_subnet.public : s.map_public_ip_on_launch] == [false, false]
    error_message = "Public subnets host the ALB only; instances get no public IP by default."
  }

  assert {
    condition = alltrue([
      for s in aws_subnet.private : contains(["eu-west-1a", "eu-west-1b", "eu-west-1c"], s.availability_zone)
    ])
    error_message = "Subnets must be pinned to real AZs from data.aws_availability_zones."
  }

  assert {
    condition     = length(aws_db_subnet_group.mssql.subnet_ids) == 2
    error_message = "The DB subnet group needs >= 2 subnets in different AZs."
  }
}

# -----------------------------------------------------------------------------
# Routing — regression cover for the plan-time count bug
# -----------------------------------------------------------------------------

run "routing_counts_are_known_at_plan_time" {
  command = plan

  # These three used to be `count = length(aws_subnet.private)`, which is
  # unknown until apply and made plan/apply/import abort with
  # "Invalid count argument". They must stay derived from
  # var.private_subnet_cidrs.
  assert {
    condition     = length(aws_route.private_nat) == 2
    error_message = "aws_route.private_nat count must be resolvable at plan time (use var.private_subnet_cidrs)."
  }

  assert {
    condition     = length(aws_route_table_association.private) == 2
    error_message = "aws_route_table_association.private count must be resolvable at plan time."
  }

  assert {
    condition     = length(aws_route_table_association.database) == 2
    error_message = "aws_route_table_association.database count must be resolvable at plan time."
  }

  assert {
    condition     = aws_route.private_nat[0].destination_cidr_block == "0.0.0.0/0"
    error_message = "Private route tables need a default route through the NAT gateway."
  }

  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "Public route table needs a default route through the internet gateway."
  }
}

# -----------------------------------------------------------------------------
# NAT gateways — single (cost) vs per-AZ (HA)
# -----------------------------------------------------------------------------

run "single_nat_gateway_mode" {
  command = plan

  variables {
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 1
    error_message = "single_nat_gateway = true must create exactly one NAT gateway."
  }

  assert {
    condition     = length(aws_eip.nat) == 1
    error_message = "One NAT gateway needs one Elastic IP."
  }
}

run "per_az_nat_gateway_mode" {
  command = plan

  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 2
    error_message = "single_nat_gateway = false must create one NAT per public subnet/AZ."
  }
}

# -----------------------------------------------------------------------------
# Flow logs + log retention
# -----------------------------------------------------------------------------

run "flow_logs" {
  command = plan

  assert {
    condition     = aws_flow_log.main.traffic_type == "ALL"
    error_message = "Prod flow logs must capture ALL traffic."
  }

  assert {
    condition     = aws_flow_log.main.log_destination_type == "cloud-watch-logs"
    error_message = "Flow logs must go to CloudWatch Logs."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs.retention_in_days == var.log_retention_days
    error_message = "Flow-log retention must follow var.log_retention_days."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs.retention_in_days == 30
    error_message = "Expected 30-day log retention (cost decision, Sept 2026)."
  }
}
