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
# Server + Redis + SonarQube + the logging stack below, all in one docker compose
# project. Rough budget at the caps set in this file: SQL Server ~2 GiB, logging
# ~1.3 GiB, SonarQube up to 3 GiB, Redis ~0.4 GiB, leaving ~1.3 GiB for the five
# APIs, Vault, nginx and the kernel.
#
# That is tight, and it is tight because of SonarQube: SonarSource's own guidance
# is 4 GB of RAM for a *small* installation, and here it runs on a 1 GB
# Elasticsearch heap next to a database server. What makes it survivable rather
# than merely optimistic is sonarqube.memory_limit_mb — the cgroup kills
# SonarQube instead of the kernel picking SQL Server as the OOM victim.
#
# If analyses start failing or SQL Server gets killed anyway, the fix is
# instance_type = "t3.xlarge" (4 vCPU / 16 GiB, roughly +$20/month at the
# 08:00-20:00 Mon-Fri schedule), not raising the caps on this one.
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
#
# REDIS_HOST/REDIS_PORT are the compose-network coordinates of the redis service
# below: every API container resolves `redis` over the same docker network, so
# there is no security group rule, no public endpoint and nothing to look up. In
# ASP.NET terms this is what goes into
# ConnectionStrings:Redis / IConnectionMultiplexer.Connect("redis:6379").
apis = {
  nomaos = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5001
    subdomain = "noma-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5000", REDIS_HOST = "redis", REDIS_PORT = "6379" }
  }
  wallet = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5001
    subdomain = "dev-wallet-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5001", REDIS_HOST = "redis", REDIS_PORT = "6379" }
  }
  onboarding = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5002
    subdomain = "dev-onboarding-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5002", REDIS_HOST = "redis", REDIS_PORT = "6379" }
  }
  input = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5003
    subdomain = "dev-input-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5003", REDIS_HOST = "redis", REDIS_PORT = "6379" }
  }
  moneval = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5004
    subdomain = "dev-moneval-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5004", REDIS_HOST = "redis", REDIS_PORT = "6379" }
  }
  serviceprovider = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5005
    subdomain = "dev-serviceprovider-api"
    env       = { ASPNETCORE_ENVIRONMENT = "Development", ASPNETCORE_URLS = "http://+:5005", REDIS_HOST = "redis", REDIS_PORT = "6379" }
  }
}

# `sonar` is deliberately NOT in this list: it is added automatically by
# local.mssql_all_databases, so it is created with the collation SonarQube
# requires and still lands in the nightly backup loop. Listing it here as well
# would be harmless (the union is deduplicated) but would create the database
# with the wrong collation if the two ever disagreed.
mssql_databases = ["wallet", "onboarding", "input", "moneval", "serviceprovider", "nomaos"]

# --- Redis (shared cache for the APIs) -----------------------------------------
# Reachable from every API container as redis:6379 over the compose network; the
# host port is published on 127.0.0.1 only and the security group has no ingress
# for it, so redis-cli from a laptop is the SSH tunnel in the `redis_access`
# output. Nothing here is reachable from the internet.
redis = {
  # A cache, not a queue: bounded at 256 MB and evicting least-recently-used
  # keys. SQL Server is on this box too, so a cache that grows without bound is
  # what takes the APIs down — maxmemory is the line that prevents that.
  maxmemory_mb     = 256
  maxmemory_policy = "allkeys-lru"

  # Off: a dev cache is allowed to be empty after a reboot, and skipping
  # persistence means no rewrite stalls and nothing to lose. Set true (and accept
  # a bind mount on the root disk) when an API stores sessions, queues or locks
  # here — and switch maxmemory_policy to "noeviction" at the same time, because
  # silently evicting a queue entry or a lock is much worse than a failed write.
  persistence = false

  # No AUTH while the port is loopback-only. Set this and it goes into SSM, is
  # fetched at boot into compose/.env and is passed as --requirepass; add
  # REDIS_PASSWORD to the API env at the same time.
  #   password = "..."   # override with TF_VAR_redis='{"password":"..."}' in CI
}

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
  allowed_cidrs = ["0.0.0.0/0"]

  # grafana_admin_password defaults to "agrovesto-dev" (dev only). Override with
  # TF_VAR_logging='{"grafana_admin_password":"..."}' in CI rather than committing
  # something better here - the file is public like the rest of this repo.
  # GitHub login is enabled automatically when DEV_GRAFANA_GITHUB_CLIENT_ID and
  # DEV_GRAFANA_GITHUB_CLIENT_SECRET are both configured as repository secrets.
  # Its callback is https://dev-logs.nomaos.com/login/github; setup is in
  # docs/github-sso.md. Infrastructure is Admin, team-leads is Editor, and
  # Backend/Frontend/mobile are Viewer. Unlisted teams are denied; the local
  # admin remains available for break-glass use.

  # An API that logs one JSON object per line should be listed here: its level,
  # status and message fields then become queryable instead of grep fodder.
  json_log_services = []
}

# --- SonarQube (code quality) --------------------------------------------------
# The server the CI pipelines already push to: SONAR_HOST_URL in the GitHub
# secrets should be set to the `sonarqube_url` output, and run-sonar.sh plus the
# sonar-project-*.properties files in the repository root need no changes.
#
# Its database is the SQL Server container on this same host, created with the
# CS_AS collation and READ_COMMITTED_SNAPSHOT that SonarSource requires (see
# local.init_sql) — neither can be changed after data exists, which is why the
# database is provisioned rather than left to SonarQube.
sonarqube = {
  # sonar.nomaos.com is served by nginx on this host. DNS for it is owned by the
  # PROD account, so add the A record there — the extra_a_records block in
  # prod/terraform.auto.tfvars has the line to copy, and the `sonarqube_fqdn` and
  # `ec2_public_ip` outputs are the two values it needs.
  subdomain = "sonar"

  # READ THIS BEFORE POINTING CI AT IT: allowed_cidrs = [] means the nginx vhost
  # answers 127.0.0.1 only, i.e. the UI is reachable through an SSH tunnel and
  # GitHub-hosted runners cannot reach it at all. To let the pipelines scan:
  #   * a self-hosted runner, or a fixed NAT egress -> add that CIDR here; or
  #   * the office/VPN egress for humans only -> add that CIDR here too.
  # GitHub-hosted runner IPs are not a fixed set, so "allow GitHub Actions" is not
  # expressible as a CIDR list. Leaving this empty keeps the box closed and CI
  # unable to reach it, which is the safer default but does mean scans fail.
  allowed_cidrs = ["0.0.0.0/0"]

  # Elasticsearch heap. SonarSource recommends half of available RAM; on this
  # 8 GiB box, shared with SQL Server, that is not an option, so it gets 1 GB and
  # analyses of anything large will be slow. Raise instance_type before raising
  # these three.
  es_java_opts  = "-Xms512m -Xmx1g"
  web_java_opts = "-Xms256m -Xmx512m"
  ce_java_opts  = "-Xms256m -Xmx512m"

  # The cgroup limit that keeps a heavy analysis from OOM-killing SQL Server:
  # when the box runs out of memory, this container dies instead of the kernel
  # choosing a victim. Set to roughly the sum of the three heaps plus off-heap.
  memory_limit_mb = 3072
  cpu_limit       = "1.00"

  # Elasticsearch indices, plugins and logs, on a volume of their own that is not
  # delete_on_termination — so replacing the instance keeps the analyses.
  volume_size_gb = 20

  # The SQL login is SonarQube's own (db_owner of the sonar database only), not
  # `sa`. The password below is a dev-only default in a public repository;
  # override it with TF_VAR_sonarqube='{"database_password":"..."}' in CI. It
  # must satisfy SQL Server's CHECK_POLICY: >=12 chars, three character classes,
  # and no part of the login name.
  # database_password = "..."

  # Local-login-only deployments retain HTTP. Supplying the four
  # SONARQUBE_GITHUB_* repository secrets adds a Caddy TLS edge, changes the
  # canonical URL to https://sonar.nomaos.com, and enables GitHub App login.
  # GitHub team membership sync is enabled; run the shipped permission bootstrap
  # once with a separate SonarQube admin token (docs/github-sso.md).
  # Caddy's certificate data survives on the SonarQube EBS volume.
  scheme = "http"
}

# =============================================================================
# Adoption of existing resources (docs/import-runbook.md, discovery 2026-09-23)
# =============================================================================
# vpc-0d9b566c353787d53. cidr_block is ForceNew, so it must be the real value.
vpc_cidr = "172.96.0.0/16"
# subnet-0739cfd4c412deb3f (eu-west-1a, IGW-routed, hosts new-noma-api)
public_subnet_cidrs = ["172.96.0.0/24"]

# --- SNS (sns.tf, alarms.tf) ---------------------------------------------------
# Each address gets an AWS confirmation email; alerts start once it is clicked.
alert_emails   = ["tech@agrovesto.com"]
app_sns_topics = ["notifications"]
