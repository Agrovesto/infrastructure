# -----------------------------------------------------------------------------
# Auto-loaded values for CI (GitHub Actions) AND local runs.
# -----------------------------------------------------------------------------
# DNS is owned by the PROD account: the prod stack manages the nomaos.com zone
# and creates this environment's records under the dev.<domain> subdomain
# (wallet.dev.nomaos.com, ...). Dev therefore serves dev.nomaos.com hostnames
domain_name = "dev.nomaos.com"

# ...and creates no Route53 zone/records of its own.
manage_dns = false
# --- Frontends (Amplify) ---
amplify_apps = {
  landing = {
    repository = "https://github.com/Agrovesto/landing"
    branch     = "dev"
    subdomain  = "landing"
    framework  = "React"
  }
  onboarding = {
    repository = "https://github.com/Agrovesto/onboarding"
    branch     = "dev"
    subdomain  = "onboarding"
    framework  = "React"
  }
}
# --- Backend APIs on the EC2 docker host ---
# TODO: replace the placeholder images with the real API images (ECR etc.)
apis = {
  wallet = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5001
    subdomain = "wallet"
    env       = { NODE_ENV = "development" }
  }
  onboarding = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5002
    subdomain = "onboarding-api"
    env       = { NODE_ENV = "development" }
  }
  input = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5003
    subdomain = "input"
  }
  moneval = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5004
    subdomain = "moneval"
  }
  serviceprovider = {
    image     = "public.ecr.aws/nginx/nginx:alpine"
    host_port = 5005
    subdomain = "serviceprovider"
  }
}
mssql_databases = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]
