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

# --- HA mode: SINGLE-AZ for now -------------------------------------------------
# RDS primary and all ECS tasks run in a single AZ (cost). For go-live HA flip
# these and apply: mssql_multi_az = true, single_az_ecs = false.
mssql_multi_az = false
single_az_ecs  = true

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
#   "wallet.dev"          = "<dev EC2 Elastic IP>"
#   "onboarding-api.dev"  = "<dev EC2 Elastic IP>"
#   "input.dev"           = "<dev EC2 Elastic IP>"
#   "moneval.dev"         = "<dev EC2 Elastic IP>"
#   "serviceprovider.dev" = "<dev EC2 Elastic IP>"
#   "vault.dev"           = "<dev EC2 Elastic IP>"
#   "mssql.dev"           = "<dev EC2 Elastic IP>"
# }
# extra_cname_records = {
#   "landing.dev"    = "dev.<landing Amplify default domain>"
#   "onboarding.dev" = "dev.<onboarding Amplify default domain>"
# }
