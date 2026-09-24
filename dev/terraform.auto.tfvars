# -----------------------------------------------------------------------------
# Auto-loaded values for CI (GitHub Actions) AND local runs.
# -----------------------------------------------------------------------------
# DNS is owned by the PROD account: the prod stack manages the nomaos.com zone
# and creates this environment's records under the dev.<domain> subdomain
# (wallet.dev.nomaos.com, ...). Dev therefore serves dev.nomaos.com hostnames
domain_name = "nomaos.com"

# ...and creates no Route53 zone/records of its own.
manage_dns = false

# --- App host ------------------------------------------------------------------
# t3.large (2 vCPU / 8 GiB): the box runs nginx + 5 API containers + Vault + SQL
# Server + the logging stack below in docker compose. SQL Server alone likes 2 GiB
# and the observability containers are capped at ~1.3 GiB together, which does not
# fit in 4 GiB with any headroom - t3.medium here means OOM kills under load.
# Drop back to t3.medium (about $11/month, given the 08:00-20:00 Mon-Fri
# schedule) and halve logging.memory_limits_mb if you would rather not pay it.
instance_type = "t3.large"
# --- Frontends (Amplify) ---
amplify_apps = {
  # Adopted: d3v79u00ot9glq / branch dev
  onboarding = {
    name       = "onboarding-frontend"
    repository = "https://github.com/Agrovesto/onboarding-frontend"
    branch     = "dev"
    subdomain  = "onboarding-dev"
    framework  = "React"
  }
  # Adopted: dfvk5chhp2iln / branch staging
  landing = {
    name       = "nomaos-landingpage"
    repository = "https://github.com/Agrovesto/nomaos-landingpage"
    branch     = "staging"
    subdomain  = "dev-agrovesto"
    framework  = "React"
  }
}
# --- Backend APIs on the EC2 docker host ---
# TODO: replace the placeholder images with the real API images (ECR etc.)
apis = {
  wallet = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5001
    subdomain = "dev-wallet-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5001" }
  }
  onboarding = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5002
    subdomain = "dev-onboarding-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5002" }
  }
  input = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5003
    subdomain = "dev-input-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5003" }
  }
  moneval = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5004
    subdomain = "dev-moneval-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5004" }
  }
  serviceprovider = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5005
    subdomain = "dev-serviceprovider-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5005" }
  }
}
mssql_databases = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]

ecr_image_tag_mutability = "MUTABLE" # dev: re-push :latest freely (prod is IMMUTABLE)
ecr_force_delete         = true      # terraform destroy may empty + delete repos
ecr_images_to_keep       = 3         # tagged images retained per repo

# --- Logging & metrics on the host --------------------------------------------
# Everything below runs as containers on this EC2 instance: Alloy tails the docker
# logs + journald, Loki stores them, Grafana queries them with LogQL, and
# Prometheus/cAdvisor/node-exporter carry the metrics. No CloudWatch, no AWS
# ingestion or per-query charges.
#
# Grafana is served by nginx at dev-logs.nomaos.com. The prod stack owns DNS, so
# add the A record there (see the extra_a_records block in
# prod/terraform.auto.tfvars) or leave it tunnel-only.
logging = {
  # Short and cheap on purpose: retention is the whole cost of a log store, and
  # the volume below is what it has to fit in (Loki chunks + Prometheus TSDB +
  # Grafana's sqlite share it).
  loki_retention_days   = 14
  system_retention_days = 5
  volume_size_gb        = 20

  # Sources allowed to reach the Grafana vhost. [] = localhost only, i.e. read it
  # through an SSH tunnel (the `logging_access` output prints the command). Add one
  # CIDR per office/VPN egress address to open it up:
  #   allowed_cidrs = ["203.0.113.10/32", "196.0.0.0/16"]
  allowed_cidrs = []

  # grafana_admin_password defaults to "agrovesto-dev" (dev only). Override with
  # TF_VAR_logging='{"grafana_admin_password":"..."}' in CI rather than committing
  # something better here - the file is public like the rest of this repo.

  # An API that logs one JSON object per line should be listed here: its level,
  # status and message fields then become queryable instead of grep fodder.
  json_log_services = []
}

# =============================================================================
# Adoption of existing resources (docs/import-runbook.md, discovery 2026-09-23)
# =============================================================================
# vpc-0d9b566c353787d53. cidr_block is ForceNew, so it must be the real value.
vpc_cidr = "172.96.0.0/16"
# subnet-0739cfd4c412deb3f (eu-west-1a, IGW-routed, hosts new-noma-api)
public_subnet_cidrs = ["172.96.0.0/24"]
