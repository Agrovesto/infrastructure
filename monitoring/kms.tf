resource "aws_kms_key" "monitoring" {
  description         = "${local.name} EFS"
  enable_key_rotation = true

  # Key policies must use Resource "*" (the policy is on the key itself); the
  # principal is the account root, and IAM policies scope the actual grants.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowRootAccountFullAccess"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  tags = merge(local.tags, { Name = "${local.name}-efs" })
}

resource "aws_kms_alias" "monitoring" {
  name          = "alias/${local.name}-efs"
  target_key_id = aws_kms_key.monitoring.key_id
}
