# =============================================================================
# ECR — one repository per API service
#
# Names follow the dev/prod convention: agrovesto-dev-wallet,
# agrovesto-dev-onboarding, ... (prod mirrors these as agrovesto-prod-<svc>).
#
# Push from your machine / app CI:
#   aws ecr get-login-password --region eu-west-1 \
#     | docker login --username AWS --password-stdin <acct>.dkr.ecr.eu-west-1.amazonaws.com
#   docker tag <img>:<tag> <acct>.dkr.ecr.eu-west-1.amazonaws.com/agrovesto-dev-<svc>:<tag>
#   docker push <acct>.dkr.ecr.eu-west-1.amazonaws.com/agrovesto-dev-<svc>:<tag>
#
# The EC2 docker host logs in to this registry in user_data and pulls with its
# instance role (EcrPullApis statement in data.tf) — no manual auth needed.
# =============================================================================
resource "aws_ecr_repository" "apis" {
  #checkov:skip=CKV_AWS_51: dev repos are tag-mutable on purpose so developers can re-push :latest; prod repos are IMMUTABLE
  for_each = var.apis
  name                 = "${local.name}-${each.key}"
  image_tag_mutability = var.ecr_image_tag_mutability
  force_delete         = var.ecr_force_delete
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    # KMS with the AWS-managed aws/ecr key (no CMK cost) — CKV_AWS_136 skipped in dev/checkov.yml.
    encryption_type = "KMS"
  }
  tags = merge(local.tags, { Service = each.key })
}
# Expire untagged digests quickly, keep the last N tagged images.
resource "aws_ecr_lifecycle_policy" "apis" {
  for_each = var.apis
  repository = aws_ecr_repository.apis[each.key].name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the last ${var.ecr_images_to_keep} tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = var.ecr_images_to_keep
        }
        action = { type = "expire" }
      }
    ]
  })
}