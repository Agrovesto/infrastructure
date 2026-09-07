mock_provider "aws" {
  source          = "../../tests/mocks"
  override_during = plan
}
variables {
  account_id               = "111111111111"
  peer_account_id          = "222222222222"
  permissions_boundary_arn = "arn:aws:iam::111111111111:policy/agrovesto-bootstrap-dev-workload-boundary"
  zone_name                = "dev.example.com"
  alert_emails             = ["test@example.com"]
  databases                = { api = "AgrovestoApi", trading = "AgrovestoTrading" }
  accept_sqlserver_eula    = true
  services_enabled         = true
  services = {
    api     = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/api:test-sha", hostname = "api", priority = 100, host_port = 8080, database_key = "api" }
    trading = { image = "222222222222.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/api:test-sha", hostname = "trading", priority = 200, host_port = 8081, database_key = "trading" }
  }
  frontends = { portal = {} }
}
run "private_dev_and_separate_disks" {
  command = plan
  assert {
    condition     = local.environment == "dev" && module.network.topology.nat_gateways == 1 && module.network.topology.app_subnets == 2 && module.network.topology.database_subnets == 2
    error_message = "Dev must use its own environment and two AZs, with one cost-optimized NAT."
  }
  assert {
    condition     = !module.host.security.public_ip && module.host.security.imds_tokens == "required" && module.host.security.imds_hops == 1
    error_message = "Dev must be private, SSM-managed, and protect host credentials with IMDSv2."
  }
  assert {
    condition     = module.host.security.root_encrypted && module.host.security.database_encrypted && module.host.security.root_size == 50 && module.host.security.database_size == 100
    error_message = "OS/API/Docker and SQL data need separate encrypted disks."
  }
  assert {
    condition     = !can(yamldecode(module.host.rendered_compose).services.mssql.ports) && yamldecode(module.host.rendered_compose).services.mssql.volumes == ["/srv/mssql:/var/opt/mssql"] && yamldecode(module.host.rendered_compose).services.mssql.environment.MSSQL_PID == "Developer"
    error_message = "SQL Server must use Developer edition, its dedicated mount and no host port."
  }
  assert {
    condition     = length(module.host.security.backup_resources) == 1 && module.host.security.backup_schedule == "cron(0 4 * * ? *)"
    error_message = "Back up the dedicated database volume daily."
  }
  assert {
    condition     = !strcontains(module.host.rendered_compose, "MSSQL_SA_PASSWORD=") && yamldecode(module.host.rendered_compose).services.api.read_only
    error_message = "Never embed secret values into Compose; API filesystems must be read-only."
  }
  assert {
    condition     = module.ecr.security.policies.api.Statement[0].Principal.AWS == "arn:aws:iam::222222222222:root" && !contains(module.ecr.security.policies.api.Statement[0].Action, "ecr:PutImage") && module.ecr.security.repositories.api.immutable == "IMMUTABLE"
    error_message = "Prod gets pull-only access to immutable dev ECR images."
  }
  assert {
    condition     = module.edge.security.redirect_protocol == "HTTPS" && length(module.frontends.apps) == 1
    error_message = "Dev API entry must redirect to HTTPS and frontends must be on Amplify."
  }
}
run "reference_existing_zone" {
  command = plan
  variables {
    existing_zone_id = "Z123456789EXAMPLE"
  }
  assert {
    condition     = module.dns.zone_id == "Z123456789EXAMPLE"
    error_message = "Existing hosted zones must be reusable without creating a second authoritative zone."
  }
}
run "reject_same_account" {
  command = plan
  variables {
    peer_account_id = "111111111111"
  }
  expect_failures = [var.peer_account_id]
}
run "reject_overlapping_ports" {
  command = plan
  variables {
    services = {
      api   = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/api:test-sha", hostname = "api", priority = 100, host_port = 8080 }
      other = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/api:test-sha", hostname = "other", priority = 200, host_port = 8080 }
    }
  }
  expect_failures = [var.services]
}

run "amplify_custom_domain_dns" {
  command = plan
  variables {
    frontends = { portal = { domain_prefix = "portal" } }
  }
  assert {
    condition     = module.frontends.managed_dns_records == 2
    error_message = "A custom Amplify domain needs both certificate validation and routing records; do not wait before creating them."
  }
}
