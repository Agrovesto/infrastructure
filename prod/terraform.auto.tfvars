# -----------------------------------------------------------------------------
# Auto-loaded values for CI (GitHub Actions) AND local runs — PROD.
# -----------------------------------------------------------------------------
# TODO: confirm the prod root domain. NOTE: the dev stack currently manages a
# zone for this same domain in the DEV account — only ONE zone can be
# authoritative at the registrar. When prod takes over the domain, delegate
# the registrar NS records to the zone created here (see
# `route53_name_servers` output) and retire/re-scope the dev zone.
domain_name = "nomaos.com"

# --- ECS services (one Fargate service per dev API name) ---------------------
# service name == database name (dev convention).
#
# TODO: the `image` values below are a PLACEHOLDER image that serves HTTP on
# $PORT so the ALB health checks pass on first apply. Build and push your real
# images to the ECR repos (agrovesto-prod-<svc>) and update these to
#   <account-id>.dkr.ecr.eu-west-1.amazonaws.com/agrovesto-prod-<svc>:<tag>
services = {
  wallet = {
    image         = "ealen/echo-server:latest"
    port          = 5001
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "wallet"
    environment   = { NODE_ENV = "production" }
  }
  onboarding = {
    image         = "ealen/echo-server:latest"
    port          = 5002
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "onboarding-api"
    environment   = { NODE_ENV = "production" }
  }
  input = {
    image         = "ealen/echo-server:latest"
    port          = 5003
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "input"
  }
  moneval = {
    image         = "ealen/echo-server:latest"
    port          = 5004
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "moneval"
  }
  serviceprovider = {
    image         = "ealen/echo-server:latest"
    port          = 5005
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "serviceprovider"
  }
}

# --- RDS SQL Server databases (same names as dev) -----------------------------
mssql_databases = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]

# Flip to true once the instance exists and you want Terraform to create the 5
# databases automatically (runs a one-off Fargate task via the AWS API).
# run_db_init = true
