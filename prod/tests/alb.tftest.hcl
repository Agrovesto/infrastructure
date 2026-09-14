# =============================================================================
# PROD — Application Load Balancer, listeners, routing, access logs
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
# Load balancer
# -----------------------------------------------------------------------------

run "load_balancer" {
  command = plan

  assert {
    condition     = aws_lb.main.name == "${var.project}-${var.environment}-alb"
    error_message = "ALB name follows the naming convention."
  }

  assert {
    condition     = aws_lb.main.load_balancer_type == "application"
    error_message = "This is an application load balancer (host-header routing)."
  }

  assert {
    condition     = aws_lb.main.internal == false
    error_message = "The prod ALB is internet-facing."
  }

  assert {
    condition     = aws_lb.main.enable_deletion_protection == true
    error_message = "Deletion protection must stay on in prod."
  }

  assert {
    condition     = aws_lb.main.drop_invalid_header_fields == true
    error_message = "Invalid header fields should be dropped."
  }

  assert {
    condition     = aws_lb.main.idle_timeout == 60
    error_message = "Idle timeout comes from var.alb_idle_timeout_seconds."
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "The ALB spans both public subnets."
  }
}

# -----------------------------------------------------------------------------
# Access logs bucket
# -----------------------------------------------------------------------------

run "access_logs" {
  command = plan

  assert {
    condition     = one(aws_lb.main.access_logs).enabled == true
    error_message = "ALB access logs must be enabled."
  }

  assert {
    condition     = one(aws_lb.main.access_logs).prefix == "alb"
    error_message = "Access logs are written under the alb/ prefix."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.alb_logs.block_public_acls == true
    error_message = "The log bucket must block public ACLs."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.alb_logs.restrict_public_buckets == true
    error_message = "The log bucket must restrict public access."
  }

  assert {
    condition = flatten([
      for r in aws_s3_bucket_server_side_encryption_configuration.alb_logs.rule : [
        for d in r.apply_server_side_encryption_by_default : d.sse_algorithm
      ]
    ]) == ["AES256"]
    error_message = "The log bucket needs default encryption."
  }

  assert {
    condition = flatten([
      for r in aws_s3_bucket_lifecycle_configuration.alb_logs.rule : [
        for e in r.expiration : e.days
      ]
    ]) == [90]
    error_message = "ALB access logs expire after var.alb_logs_retention_days (90)."
  }

  assert {
    condition     = aws_s3_bucket.alb_logs.force_destroy == false
    error_message = "The prod log bucket must not be force-destroyable."
  }
}

# -----------------------------------------------------------------------------
# Target groups
# -----------------------------------------------------------------------------

run "target_groups" {
  command = plan

  assert {
    condition     = length(aws_lb_target_group.services) == 5
    error_message = "One target group per service."
  }

  assert {
    condition     = aws_lb_target_group.services["wallet"].port == 5001
    error_message = "Target group port must match the service port."
  }

  assert {
    condition     = aws_lb_target_group.services["wallet"].target_type == "ip"
    error_message = "Fargate needs ip targets."
  }

  assert {
    condition     = aws_lb_target_group.services["wallet"].protocol == "HTTP"
    error_message = "TLS terminates at the ALB; targets speak HTTP."
  }

  assert {
    condition     = one(aws_lb_target_group.services["wallet"].health_check).path == "/"
    error_message = "Default health-check path is the service's health_check_path (/)."
  }

  assert {
    condition     = aws_lb_target_group.services["wallet"].deregistration_delay == 30
    error_message = "Keep the 30s deregistration delay for fast deploys."
  }
}

# -----------------------------------------------------------------------------
# Listeners
# -----------------------------------------------------------------------------

run "listeners" {
  command = plan

  assert {
    condition     = aws_lb_listener.http.port == 80
    error_message = "Port 80 exists only to redirect."
  }

  assert {
    condition     = [for a in aws_lb_listener.http.default_action : a.type] == ["redirect"]
    error_message = "HTTP must redirect to HTTPS."
  }

  assert {
    condition = flatten([
      for a in aws_lb_listener.http.default_action : [
        for r in a.redirect : r.status_code
      ]
    ]) == ["HTTP_301"]
    error_message = "The redirect is a permanent 301."
  }

  assert {
    condition     = aws_lb_listener.https.port == 443
    error_message = "HTTPS listener on 443."
  }

  assert {
    condition     = aws_lb_listener.https.protocol == "HTTPS"
    error_message = "HTTPS listener terminates TLS with the ACM certificate."
  }

  assert {
    condition     = aws_lb_listener.https.ssl_policy == var.alb_tls_policy
    error_message = "TLS policy must come from var.alb_tls_policy."
  }

  assert {
    condition     = [for a in aws_lb_listener.https.default_action : a.type] == ["fixed-response"]
    error_message = "Unknown hosts get a fixed 404 rather than a service."
  }
}

# -----------------------------------------------------------------------------
# Host-header routing
# -----------------------------------------------------------------------------

run "listener_rules" {
  command = plan

  assert {
    condition     = length(aws_lb_listener_rule.services) == 5
    error_message = "One listener rule per service."
  }

  assert {
    condition     = aws_lb_listener_rule.services["input"].priority == 1
    error_message = "Rule priorities are assigned by sorted service key, starting at 1."
  }

  assert {
    condition     = aws_lb_listener_rule.services["wallet"].priority == 5
    error_message = "Rule priorities are assigned by sorted service key."
  }

  assert {
    condition = flatten([
      for c in aws_lb_listener_rule.services["wallet"].condition : [
        for h in c.host_header : h.values
      ]
    ]) == ["wallet-api.nomaos.com"]
    error_message = "Rules route the service's <subdomain>.<domain> to its target group."
  }

  assert {
    condition     = [for a in aws_lb_listener_rule.services["wallet"].action : a.type] == ["forward"]
    error_message = "Rules forward to the service target group."
  }
}

run "listener_rules_follow_the_domain_variable" {
  command = plan

  variables {
    domain_name = "example.com"
  }

  assert {
    condition = flatten([
      for c in aws_lb_listener_rule.services["wallet"].condition : [
        for h in c.host_header : h.values
      ]
    ]) == ["wallet-api.example.com"]
    error_message = "Host-header conditions must follow var.domain_name."
  }
}
