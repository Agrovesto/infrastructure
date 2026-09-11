# =============================================================================
# Security groups
#
#   Internet -> ALB SG (80/443) -> ECS SG (service ports, ALB only)
#   ECS SG -> RDS SG (1433, ECS tasks only)
# =============================================================================

# Public HTTP/HTTPS ingress is the whole point of the load balancer - mirrors checkov CKV_AWS_260 skip.
#trivy:ignore:AVD-AWS-0107
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Public ALB: 80/443 from the internet, egress to the ECS tasks only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP (redirects to HTTPS)"
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

  tags = merge(local.tags, { Name = "${local.name}-alb-sg" })
}

# Tasks need unrestricted outbound for ECR pulls, CloudWatch and Secrets Manager - mirrors checkov CKV_AWS_382 skip.
#trivy:ignore:AVD-AWS-0104
resource "aws_security_group" "ecs" {
  name        = "${local.name}-ecs-sg"
  description = "ECS Fargate tasks: service ports from the ALB only"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Unrestricted outbound (ECR image pulls, CloudWatch logs, Secrets Manager, RDS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-ecs-sg" })
}

# ALB -> ECS tasks: one egress rule per distinct service port (services + Vault).
resource "aws_security_group_rule" "alb_to_ecs" {
  for_each = toset([for p in local.service_ports : tostring(p)])

  type                     = "egress"
  description              = "To ECS tasks on port ${each.key}"
  from_port                = tonumber(each.key)
  to_port                  = tonumber(each.key)
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ecs.id
}

# ECS tasks <- ALB: one ingress rule per distinct service port, ALB only.
resource "aws_security_group_rule" "ecs_from_alb" {
  for_each = toset([for p in local.service_ports : tostring(p)])

  type                     = "ingress"
  description              = "From ALB on port ${each.key}"
  from_port                = tonumber(each.key)
  to_port                  = tonumber(each.key)
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "RDS SQL Server: 1433 from the ECS tasks only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SQL Server from ECS tasks"
    from_port       = var.mssql_port
    to_port         = var.mssql_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = merge(local.tags, { Name = "${local.name}-rds-sg" })
}

resource "aws_security_group" "efs" {
  #checkov:skip=CKV2_AWS_5: attached to the EFS mount targets via aws_efs_mount_target.vault (checkov cannot trace mount-target attachments)
  count = var.enable_vault ? 1 : 0

  name        = "${local.name}-efs-sg"
  description = "Vault EFS: NFS from the ECS tasks only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from ECS tasks (Vault raft storage)"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = merge(local.tags, { Name = "${local.name}-efs-sg" })
}
