# Bootstrap import for the PROD account (221434544570).
#   AWS_PROFILE=agrovesto-prod terraform plan -state=prod.tfstate -var-file=prod.tfvars
account_id           = "221434544570"
deploy_role_name     = "agrovesto-prod-github-deploy" # created by this module
import_deploy_policy = true
