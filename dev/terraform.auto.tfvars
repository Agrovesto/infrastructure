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
# t3.medium (2 vCPU / 4 GiB) runs nginx + 5 API containers + Vault + SQL Server
# in docker compose. Bump back to t3.xlarge if the host runs hot.
instance_type = "t3.medium"
# --- Frontends (Amplify) ---
amplify_apps = {
  landing = {
    repository = "https://github.com/Agrovesto/nomaos-landingpage"
    branch     = "dev"
    subdomain  = "dev-agrovesto"
    framework  = "React"
  }
  onboarding = {
    repository = "https://github.com/Agrovesto/onboarding-frontend"
    branch     = "dev"
    subdomain  = "onboarding-dev"
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
ecr_images_to_keep       = 3        # tagged images retained per repo