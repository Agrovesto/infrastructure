resource "aws_security_group" "admin" {
  #checkov:skip=CKV2_AWS_5:Used by the one-off ECS admin task through the exported run-task network configuration, not a continuously running service.

  name        = "${var.name}-sql-admin"
  description = "One-off private SQL provisioning task, no ingress"
  vpc_id      = var.vpc_id
}
resource "aws_vpc_security_group_egress_rule" "admin_https" {
  security_group_id = aws_security_group.admin.id
  description       = "HTTPS via NAT for ECR, logs and Secrets Manager"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
resource "aws_vpc_security_group_egress_rule" "admin_sql" {
  security_group_id            = aws_security_group.admin.id
  referenced_security_group_id = var.database_security_group_id
  description                  = "Provision SQL Server databases and per-API logins"
  ip_protocol                  = "tcp"
  from_port                    = 1433
  to_port                      = 1433
}
resource "aws_cloudwatch_log_group" "admin" {
  name              = "/${var.name}/ecs/sql-admin"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}
resource "aws_iam_role" "admin_execution" {
  name                 = "${var.name}-sql-admin-execution"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy   = local.task_trust
}
resource "aws_iam_role_policy" "admin_execution" {
  role = aws_iam_role.admin_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"], Resource = var.ecr_repository_arns },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.admin.arn}:*" }
    ]
  })
}
resource "aws_iam_role" "admin" {
  name                 = "${var.name}-sql-admin-task"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy   = local.task_trust
}
resource "aws_iam_role_policy" "admin" {
  role = aws_iam_role.admin.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = var.database_master_secret_arn },
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:PutSecretValue"], Resource = values(var.database_secret_arns) },
      { Effect = "Allow", Action = ["secretsmanager:GetRandomPassword"], Resource = "*" },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"], Resource = var.kms_key_arn }
    ]
  })
}
resource "aws_ecs_task_definition" "admin" {
  family                   = "${var.name}-sql-admin"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.admin_execution.arn
  task_role_arn            = aws_iam_role.admin.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([{
    name                   = "sql-admin"
    image                  = var.sql_admin_image
    essential              = true
    user                   = "10001:10001"
    readonlyRootFilesystem = true
    linuxParameters        = { capabilities = { drop = ["ALL"] }, initProcessEnabled = true }
    environment = [{ name = "DB_CONFIG", value = jsonencode({
      environment      = "prod", region = var.region, db_host = var.database_host
      admin_secret_arn = var.database_master_secret_arn
      databases        = { for key, name in var.databases : key => { name = name, secret_arn = var.database_secret_arns[key] } }
    }) }]
    logConfiguration = {
      logDriver = "awslogs"
      options   = { awslogs-group = aws_cloudwatch_log_group.admin.name, awslogs-region = var.region, awslogs-stream-prefix = "admin" }
    }
  }])
}
