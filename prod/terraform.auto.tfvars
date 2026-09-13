# -----------------------------------------------------------------------------
# Auto-loaded values for CI (GitHub Actions) AND local runs — PROD.
# -----------------------------------------------------------------------------
# The PROD account is authoritative for the root domain: this stack creates the
# hosted zone and every record in it (prod service aliases AND the dev hosts —
# dev manages no DNS itself; see the extra_a_records block below).
# ACTION: delegate the registrar NS records for this domain to the zone created
# here (see the `route53_name_servers` output).
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
    subdomain     = "wallet-api"
    environment   = { ASPNETCORE_ENVIRONMENT = "Production", ASPNETCORE_URLS = "http://+:5001" }
  }
  onboarding = {
    image         = "ealen/echo-server:latest"
    port          = 5002
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "onboarding-api"
    environment   = { ASPNETCORE_ENVIRONMENT = "Production", ASPNETCORE_URLS = "http://+:5002" }
  }
  input = {
    image         = "ealen/echo-server:latest"
    port          = 5003
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "input-api"
    environment   = { ASPNETCORE_ENVIRONMENT = "Production", ASPNETCORE_URLS = "http://+:5003" }
  }
  moneval = {
    image         = "ealen/echo-server:latest"
    port          = 5004
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "moneval-api"
    environment   = { ASPNETCORE_ENVIRONMENT = "Production", ASPNETCORE_URLS = "http://+:5004" }
  }
  serviceprovider = {
    image         = "ealen/echo-server:latest"
    port          = 5005
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "serviceprovider-api"
    environment   = { ASPNETCORE_ENVIRONMENT = "Production", ASPNETCORE_URLS = "http://+:5005" }
  }
}

# --- RDS SQL Server databases (same names as dev) -----------------------------
mssql_databases = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]

# --- ECR (API image repos) ---------------------------------------------------
# Repos are created from the `apis` map above (agrovesto-dev-<svc>). Push with
# `terraform output ecr_repository_urls`; the EC2 host self-authenticates.
ecr_image_tag_mutability = "IMMUTABLE" # prod: release tags cannot be overwritten
ecr_force_delete         = false       # prod: never delete repos that still hold images
ecr_images_to_keep       = 5           # tagged images retained per repo


# --- HA mode: SINGLE-AZ for now -------------------------------------------------
# RDS primary and all ECS tasks run in a single AZ (cost). For go-live HA flip
# these and apply: mssql_multi_az = true, single_az_ecs = false.
mssql_multi_az = false
single_az_ecs  = true

# --- Cost tuning ----------------------------------------------------------------
# CloudWatch: 30-day retention for service logs and VPC flow logs.
log_retention_days = 30

# One shared NAT gateway instead of one per AZ: saves ~$35/mo, costs AZ
# redundancy on private-subnet egress. Flip to false for go-live HA.
single_nat_gateway = true

# --- ECS autoscaling ------------------------------------------------------------
# One task stays warm per service (the ALB cannot wake a service from zero —
# with no healthy target it returns 503), scaling out on request load up to 4
# tasks. Tune requests-per-task once there is real traffic.
ecs_autoscaling_enabled           = true
ecs_autoscaling_min_capacity      = 1
ecs_autoscaling_max_capacity      = 4
ecs_autoscaling_requests_per_task = 1000

# --- RDS storage ----------------------------------------------------------------
# 50 GB provisioned, autoscaling ceiling 100 GB (gp3).
mssql_allocated_storage_gb     = 50
mssql_max_allocated_storage_gb = 100

# --- Vault ----------------------------------------------------------------------
# Vault (secrets store) is provisioned by default; services still get DB creds
# injected from Secrets Manager until Vault is initialized. Bootstrap steps and
# the switch to vault_secrets_enabled = true are documented in vault.tf.
# enable_vault           = false   # to remove the Vault service entirely
# vault_secrets_enabled  = true    # after `vault operator init` + kv bootstrap

# Flip to true once the instance exists and you want Terraform to create the 5
# databases automatically (runs a one-off Fargate task via the AWS API).
# run_db_init = true

# --- Dev DNS records (managed from THIS zone) ---------------------------------
# Dev runs under the dev.<domain> subdomain and creates no DNS of its own.
# Fill these from the dev stack outputs after a dev apply:
#   terraform -chdir=../dev output ec2_public_ip frontend_default_domains
#
# extra_a_records = {
#   "dev-wallet-api"          = "<dev EC2 Elastic IP>"
#   "dev-onboarding-api"      = "<dev EC2 Elastic IP>"
#   "dev-input.api"           = "<dev EC2 Elastic IP>"
#   "dev-moneval-api"         = "<dev EC2 Elastic IP>"
#   "dev-serviceprovider-api" = "<dev EC2 Elastic IP>"
#   "dev-vault"           = "<dev EC2 Elastic IP>"
# }
# extra_cname_records = {
#   "landing.dev"    = "dev.<landing Amplify default domain>"
#   "onboarding.dev" = "dev.<onboarding Amplify default domain>"
# }
