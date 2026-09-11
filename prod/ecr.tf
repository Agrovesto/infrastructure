# =============================================================================
# ECR — one repository per service
#
# Repository names follow the dev naming convention:
#   agrovesto-prod-wallet, agrovesto-prod-onboarding, ...
# Push images with:
#   docker tag <img>:<tag> <acct>.dkr.ecr.<region>.amazonaws.com/agrovesto-prod-<svc>:<tag>
# docker push ...
# =============================================================================

resource "aws_ecr_repository" "services" {
  for_each = var.services

  name                 = "${local.name}-${each.key}"
  image_tag_mutability = var.ecr_image_tag_mutability
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    # KMS with the AWS-managed aws/ecr key (no CMK cost).
    encryption_type = "KMS"
  }

  tags = merge(local.tags, { Service = each.key })
}

# Keep the last N tagged images, expire untagged digests quickly.
resource "aws_ecr_lifecycle_policy" "services" {
  for_each = var.services

  repository = aws_ecr_repository.services[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 14 days"
        selection    = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the last ${var.ecr_images_to_keep} tagged images"
        selection    = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = var.ecr_images_to_keep
        }
        action       = { type = "expire" }
      }
    ]
  })
}
