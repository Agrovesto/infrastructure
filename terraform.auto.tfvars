# -----------------------------------------------------------------------------
# Auto-loaded values for CI (GitHub Actions) AND local runs.
# -----------------------------------------------------------------------------
# TODO: set the real root domain (must match the Route53 hosted zone / registrar)
domain_name = "nomaos.com"
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
