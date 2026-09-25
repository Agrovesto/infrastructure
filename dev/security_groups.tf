# =============================================================================
# Security groups
# =============================================================================

# Dev EC2 needs outbound internet (docker pulls, S3 backups, GitHub) - mirrors checkov CKV_AWS_382 skip.
# SSH source is var.allowed_ssh_cidrs (restrict in tfvars when ready) - mirrors checkov CKV_AWS_24 skip.
#trivy:ignore:AVD-AWS-0104
#trivy:ignore:AVD-AWS-0107
resource "aws_security_group" "ec2" {
  name        = "${local.name}-ec2-sg"
  description = "Nginx + SSH for public EC2 (APIs, Vault, MSSQL via nginx)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "Unrestricted outbound (docker pulls, S3 backups, GitHub)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-ec2-sg" })
}
