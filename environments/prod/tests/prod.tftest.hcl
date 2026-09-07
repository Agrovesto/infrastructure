mock_provider "aws" {
  source          = "../../tests/mocks"
  override_during = plan
}
variables {
  account_id               = "222222222222"
  peer_account_id          = "111111111111"
  permissions_boundary_arn = "arn:aws:iam::222222222222:policy/agrovesto-bootstrap-prod-workload-boundary"
  zone_name                = "example.com"
  alert_emails             = ["test@example.com"]
  databases                = { api = "AgrovestoApi" }
  services_enabled         = true
  sql_admin_image          = "222222222222.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/sql-admin@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  services = {
    api    = { image = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", hostname = "api", priority = 100, database_key = "api" }
    portal = { image = "222222222222.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/web@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", hostname = "", priority = 200, health_path = "/" }
  }
}
run "high_availability_and_sqlserver" {
  command = plan
  assert {
    condition     = local.environment == "prod" && module.network.topology.nat_gateways == 2 && module.network.topology.database_subnets == 2
    error_message = "Prod needs two AZs with one NAT per AZ and isolated DB subnets."
  }
  assert {
    condition     = module.database.security.engine == "sqlserver-se" && module.database.security.license_model == "license-included" && module.database.security.port == 1433
    error_message = "Prod must use licensed RDS SQL Server Standard, not MySQL or Developer edition."
  }
  assert {
    condition     = module.database.security.multi_az && module.database.security.encrypted && !module.database.security.public && module.database.security.managed_password && module.database.security.tls_required == "1"
    error_message = "Require Multi-AZ private encrypted RDS, AWS-managed master credentials and forced TLS."
  }
  assert {
    condition     = module.database.security.backup_days == 35 && module.database.security.deletion_protection && module.database.security.final_snapshot
    error_message = "Production data must have 35-day backups and deletion/final snapshot protections."
  }
  assert {
    condition     = module.edge.security.waf_count == 1 && module.edge.security.waf_associations == 1 && module.edge.security.waf_log_configs == 1 && module.edge.security.deletion_protected
    error_message = "Prod must always enable an associated, logged WAF and protect the ALB from deletion."
  }
  assert {
    condition     = module.services.security.running_services == 2 && alltrue([for s in values(module.services.security.services) : !s.public_ip && s.desired_count >= 2 && s.rollback])
    error_message = "All prod frontends/APIs run on private ECS with at least two tasks and deployment rollback."
  }
  assert {
    condition     = alltrue([for task in values(module.services.security.tasks) : task.network_mode == "awsvpc" && contains(task.compatibility, "FARGATE") && task.containers[0].readonlyRootFilesystem && task.containers[0].user == "10001:10001"])
    error_message = "ECS tasks must be non-root, read-only Fargate containers."
  }
  assert {
    condition     = length(module.services.security.tasks.api.containers[0].secrets) == 2 && length(module.services.security.tasks.portal.containers[0].secrets) == 0 && length(module.services.security.database_clients) == 1 && contains(module.services.security.database_clients, "api")
    error_message = "Only database-backed APIs may access SQL Server or database credentials; frontend tasks must not."
  }
  assert {
    condition     = module.ecr.security.policies.api.Statement[0].Principal.AWS == "arn:aws:iam::111111111111:root" && !contains(module.ecr.security.policies.api.Statement[0].Action, "ecr:PutImage")
    error_message = "Dev gets pull-only, never push/admin, access to production repositories."
  }
}
run "scaffold_before_publishing_images" {
  command = plan
  variables {
    services_enabled = false
    sql_admin_image  = null
  }
  assert {
    condition     = module.services.security.running_services == 0 && length(module.services.security.tasks) == 2
    error_message = "A first scaffold must not start services whose images/DB credentials are not ready."
  }
}
run "reject_mutable_production_image" {
  command = plan
  variables {
    services = { api = { image = "222222222222.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/api:mutable-tag", hostname = "api", priority = 100 } }
  }
  expect_failures = [var.services]
}
run "reject_single_task_production" {
  command = plan
  variables {
    services = { api = { image = "222222222222.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", hostname = "api", priority = 100, min_count = 1 } }
  }
  expect_failures = [var.services]
}
run "reject_invalid_fargate_memory" {
  command = plan
  variables {
    services = { api = { image = "222222222222.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", hostname = "api", priority = 100, cpu = 256, memory = 8192 } }
  }
  expect_failures = [var.services]
}

run "reject_cross_database_secret_injection" {
  command = plan
  variables {
    services = { api = {
      image    = "222222222222.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      hostname = "api", priority = 100
      secrets  = { OTHER_DATABASE = "arn:aws:secretsmanager:eu-west-1:222222222222:secret:agrovesto/prod/sql/other-AbCdEf:password::" }
    } }
  }
  expect_failures = [var.services]
}
