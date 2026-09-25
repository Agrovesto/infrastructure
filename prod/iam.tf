# =============================================================================
# IAM — ECS task execution role + RDS enhanced monitoring role
# =============================================================================

# Execution role: used by the ECS agent/Fargate to pull from ECR, push logs to
# CloudWatch and inject the SQL Server credentials from Secrets Manager.
resource "aws_iam_role" "ecs_execution" {
  name               = "${local.name}-ecs-execution-role"
  assume_role_policy = can(jsondecode(data.aws_iam_policy_document.ecs_execution_assume.json)) ? data.aws_iam_policy_document.ecs_execution_assume.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name   = "${local.name}-ecs-execution-secrets"
  role   = aws_iam_role.ecs_execution.id
  policy = can(jsondecode(data.aws_iam_policy_document.ecs_execution_secrets.json)) ? data.aws_iam_policy_document.ecs_execution_secrets.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
}

# Injecting the same master secret into every service would defeat secret
# isolation; instead grant each task role read access so a later per-service
# secret can be swapped in without an IAM change.
resource "aws_iam_role" "ecs_task" {
  name               = "${local.name}-ecs-task-role"
  assume_role_policy = can(jsondecode(data.aws_iam_policy_document.ecs_execution_assume.json)) ? data.aws_iam_policy_document.ecs_execution_assume.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"

  tags = local.tags
}

# Enhanced monitoring for the RDS instance.
# Reuses var.mssql_monitoring_role_arn when set (adopted instance already has
# rds-monitoring-role) so no duplicate role is created.
locals {
  rds_monitoring_role_arn = var.mssql_monitoring_role_arn != "" ? var.mssql_monitoring_role_arn : aws_iam_role.rds_monitoring[0].arn
}

resource "aws_iam_role" "rds_monitoring" {
  count = var.mssql_monitoring_role_arn == "" ? 1 : 0

  name               = "${local.name}-rds-monitoring-role"
  assume_role_policy = can(jsondecode(data.aws_iam_policy_document.rds_monitoring_assume.json)) ? data.aws_iam_policy_document.rds_monitoring_assume.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.mssql_monitoring_role_arn == "" ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
