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
  databases = {
    core          = "AgrovestoCore"
    auth          = "AgrovestoAuth"
    trading       = "AgrovestoTrading"
    catalog       = "AgrovestoCatalog"
    notifications = "AgrovestoNotifications"
  }
  accept_sqlserver_eula = true
  services_enabled      = true
  services = {
    core          = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/core:test-sha", hostname = "api", priority = 100, host_port = 8080, database_key = "core" }
    auth          = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/auth:test-sha", hostname = "auth", priority = 110, host_port = 8081, database_key = "auth" }
    trading       = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/trading:test-sha", hostname = "trading", priority = 120, host_port = 8082, database_key = "trading" }
    catalog       = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/catalog:test-sha", hostname = "catalog", priority = 130, host_port = 8083, database_key = "catalog" }
    notifications = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/notifications:test-sha", hostname = "notifications", priority = 140, host_port = 8084, database_key = "notifications" }
  }
  frontends = {
    portal = { domain_prefix = "portal" }
    admin  = { domain_prefix = "admin" }
  }
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
    condition     = !strcontains(module.host.rendered_compose, "MSSQL_SA_PASSWORD=") && yamldecode(module.host.rendered_compose).services.core.read_only
    error_message = "Never embed secret values into Compose; API filesystems must be read-only."
  }
  assert {
    condition     = length(yamldecode(module.host.rendered_compose).services) == 6
    error_message = "Dev Compose must include mssql plus the five APIs."
  }
  assert {
    condition     = module.ecr.security.policies.core.Statement[0].Principal.AWS == "arn:aws:iam::222222222222:root" && !contains(module.ecr.security.policies.core.Statement[0].Action, "ecr:PutImage") && module.ecr.security.repositories.core.immutable == "IMMUTABLE"
    error_message = "Prod gets pull-only access to immutable dev ECR images."
  }
  assert {
    condition     = module.edge.security.redirect_protocol == "HTTPS" && length(module.frontends.apps) == 2
    error_message = "Dev API entry must redirect to HTTPS and both frontends must be on Amplify."
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
      core  = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/core:test-sha", hostname = "api", priority = 100, host_port = 8080 }
      other = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/core:test-sha", hostname = "other", priority = 200, host_port = 8080 }
    }
  }
  expect_failures = [var.services]
}

run "amplify_custom_domain_dns" {
  command = plan
  variables {
    frontends = {
      portal = { domain_prefix = "portal" }
      admin  = { domain_prefix = "admin" }
    }
  }
  assert {
    condition     = module.frontends.managed_dns_records == 4
    error_message = "Each custom Amplify domain needs certificate validation and routing records."
  }
}
