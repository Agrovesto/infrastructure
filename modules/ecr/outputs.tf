output "repository_urls" {
  value = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}
output "repository_arns" {
  value = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}
output "security" {
  value = {
    policies = { for k, policy in aws_ecr_repository_policy.pull : k => jsondecode(policy.policy) }
    repositories = { for k, repo in aws_ecr_repository.this : k => {
      immutable  = repo.image_tag_mutability
      scan       = repo.image_scanning_configuration[0].scan_on_push
      encryption = one(repo.encryption_configuration).encryption_type
    } }
  }
}
