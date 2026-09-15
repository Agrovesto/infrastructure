# Policies are written with jsonencode rather than aws_iam_policy_document so
# the config renders valid JSON under the mock provider used by the test suite.

locals {
  ecs_tasks_assume = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  events_assume = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = ["events.amazonaws.com", "scheduler.amazonaws.com"] }
    }]
  })

  params_arn = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.param}"
}

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution-role"
  assume_role_policy = local.ecs_tasks_assume

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The execution role also pulls the SSM SecureStrings ECS injects as container
# secrets (the Grafana admin password).
resource "aws_iam_role_policy" "execution_ssm" {
  name = "${local.name}-execution-ssm"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadConfigParameters"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = ["${local.params_arn}", "${local.params_arn}/*"]
      },
      {
        Sid      = "DecryptConfigParameters"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/${local.name}-efs"]
      }
    ]
  })
}

resource "aws_iam_role" "task" {
  name               = "${local.name}-task-role"
  assume_role_policy = local.ecs_tasks_assume

  tags = local.tags
}

resource "aws_iam_role_policy" "task" {
  name = "${local.name}-task-policy"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid      = "ListConfigBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.config.arn]
      },
      {
        Sid      = "ReadConfigObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.config.arn}/config/*"]
      },
      {
        Sid      = "DecryptConfigParameters"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/${local.name}-efs"]
      },
      {
        Sid      = "MountMonitoringVolumes"
        Effect   = "Allow"
        Action   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
        Resource = [aws_efs_file_system.monitoring.arn]
      },
      {
        Sid      = "UseMonitoringKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
        Resource = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/${local.name}-efs"]
      },
      {
        # ECS Exec (enable_execute_command) opens a shell through SSM.
        Sid    = "EcsExec"
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = ["*"]
      }
    ],
    var.enable_cost_monitoring ? [
      {
        Sid      = "ReadCostAndUsageReport"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = ["arn:aws:s3:::${local.cur_bucket}", "arn:aws:s3:::${local.cur_bucket}/*"]
      }
    ] : [],
    var.enable_ecs_monitoring ? [
      {
        Sid      = "ListEcsResources"
        Effect   = "Allow"
        Action   = ["ecs:ListClusters", "ecs:ListServices", "ecs:ListTasks"]
        Resource = ["*"]
      },
      {
        Sid    = "DescribeEcsResources"
        Effect = "Allow"
        Action = ["ecs:DescribeClusters", "ecs:DescribeServices", "ecs:DescribeTasks"]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${local.ecs_cluster}",
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${local.ecs_cluster}/*",
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task/${local.ecs_cluster}/*"
        ]
      }
    ] : [],
    var.enable_ecs_log_shipping ? [
      {
        Sid      = "ListLogGroups"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = ["*"]
      },
      {
        Sid      = "ReadServiceLogs"
        Effect   = "Allow"
        Action   = ["logs:FilterLogEvents", "logs:GetLogEvents"]
        Resource = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${local.ecs_log_prefix}*:*"]
      }
    ] : [],
    local.mssql_enabled ? [
      {
        Sid      = "ReadDatabaseSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = ["arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.mssql_secret_name}*"]
      },
      {
        Sid      = "DecryptDatabaseSecret"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = ["*"]
        Condition = {
          StringEquals = { "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com" }
        }
      }
    ] : [])
  })
}

# The scheduled tasks (cost report, SQL Server metrics) are started by
# EventBridge, which needs both RunTask and permission to hand over task roles.
resource "aws_iam_role" "events" {
  count = var.enable_cost_monitoring || local.mssql_enabled || local.collector_enabled ? 1 : 0

  name               = "${local.name}-events-role"
  assume_role_policy = local.events_assume

  tags = local.tags
}

resource "aws_iam_role_policy" "events" {
  count = var.enable_cost_monitoring || local.mssql_enabled || local.collector_enabled ? 1 : 0

  name = "${local.name}-events-policy"
  role = aws_iam_role.events[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RunScheduledTasks"
        Effect = "Allow"
        Action = ["ecs:RunTask"]
        Resource = concat(
          var.enable_cost_monitoring ? ["arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.name}-budget:*"] : [],
          local.mssql_enabled ? ["arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.name}-mssql-metrics:*"] : [],
          local.collector_enabled ? ["arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.name}-ecs-collector:*"] : []
        )
      },
      {
        Sid      = "PassTaskRoles"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [aws_iam_role.execution.arn, aws_iam_role.task.arn]
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      }
    ]
  })
}
