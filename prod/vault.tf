# =============================================================================
# HashiCorp Vault — secrets store for the prod services
#
# One Fargate task (private subnets), raft storage on EFS, AWS KMS auto-unseal,
# published as https://vault.<domain> through the ALB (TLS terminates at the
# ALB, like the other services).
#
# Day-2 bootstrap (once after the first apply):
#   1. `vault operator init -key-shares=1 -key-threshold=1`
#      (auto-unseal is active, so init only yields the ROOT TOKEN — store it in
#      Secrets Manager as your Vault break-glass admin credential)
#   2. Enable kv-v2 and write per-service secrets, e.g.:
#      vault secrets enable -path=kv kv-v2
#      vault kv put kv/wallet    username=... password=...
#      vault kv put kv/onboarding ...  (one path per database/service)
#      (the RDS master credentials output/value can seed these)
#   3. Set `vault_secrets_enabled = true` in terraform.auto.tfvars and apply:
#      services stop getting DB_USER/DB_PASSWORD injected from Secrets Manager
#      and read from Vault instead (they always receive VAULT_ADDR).
# =============================================================================

# -- KMS: auto-unseal + EFS encryption ------------------------------------------

# Explicit key policy: account root delegation (the standard AWS baseline).
data "aws_iam_policy_document" "vault_kms" {
  #checkov:skip=CKV_AWS_109: KMS key policies must use Resource "*" (the policy applies to the key itself); the principal is the account root only
  #checkov:skip=CKV_AWS_111: KMS key policies must use Resource "*" (the policy applies to the key itself); the principal is the account root only
  #checkov:skip=CKV_AWS_356: KMS key policies must use Resource "*" (the policy applies to the key itself); the principal is the account root only
  statement {
    sid    = "AllowRootAccountFullAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_key" "vault" {
  description         = "${local.name} Vault (auto-unseal) + Vault EFS encryption"
  policy              = data.aws_iam_policy_document.vault_kms.json
  enable_key_rotation = true

  tags = merge(local.tags, { Name = "${local.name}-vault" })
}

resource "aws_kms_alias" "vault" {
  count = var.enable_vault ? 1 : 0

  name          = "alias/${local.name}-vault"
  target_key_id = aws_kms_key.vault.key_id
}

# -- EFS: raft storage ------------------------------------------------------------

resource "aws_efs_file_system" "vault" {
  #checkov:skip=CKV_AWS_184: encrypted with the stack's own CMK (aws_kms_key.vault) which checkov cannot always trace
  count = var.enable_vault ? 1 : 0

  creation_token = "${local.name}-vault"
  encrypted      = true
  kms_key_id     = aws_kms_key.vault.arn

  tags = merge(local.tags, { Name = "${local.name}-vault" })
}

resource "aws_efs_access_point" "vault" {
  count = var.enable_vault ? 1 : 0

  file_system_id = aws_efs_file_system.vault[0].id

  # vault container runs as uid/gid 100.
  posix_user {
    uid = 100
    gid = 100
  }

  root_directory {
    path = "/vault"
    creation_info {
      owner_uid   = 100
      owner_gid   = 100
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Name = "${local.name}-vault" })
}

resource "aws_efs_mount_target" "vault" {
  # Known at plan time (see the note in vpc.tf): count must not be derived
  # from aws_subnet.private, whose length is unknown until apply.
  count = var.enable_vault ? length(var.private_subnet_cidrs) : 0

  file_system_id  = aws_efs_file_system.vault[0].id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs[0].id]
}

# -- IAM: the Vault task needs KMS for auto-unseal --------------------------------

data "aws_iam_policy_document" "vault_task" {
  #checkov:skip=CKV_AWS_355: KMS permissions are scoped to the stack's own Vault key
  statement {
    sid       = "VaultAutoUnseal"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.vault.arn]
  }
}

resource "aws_iam_role" "vault_task" {
  count = var.enable_vault ? 1 : 0

  name               = "${local.name}-vault-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_assume.json != "" ? data.aws_iam_policy_document.ecs_execution_assume.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"

  tags = local.tags
}

resource "aws_iam_role_policy" "vault_task" {
  count = var.enable_vault ? 1 : 0

  name   = "${local.name}-vault-task-policy"
  role   = aws_iam_role.vault_task[0].id
  policy = data.aws_iam_policy_document.vault_task.json != "" ? data.aws_iam_policy_document.vault_task.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
}

# -- ECS service ------------------------------------------------------------------

# CloudWatch default encryption is enough here too - mirrors checkov CKV_AWS_158 skip.
#trivy:ignore:AVD-AWS-0017
resource "aws_cloudwatch_log_group" "vault" {
  count = var.enable_vault ? 1 : 0

  name              = "/ecs/${local.name}/vault"
  retention_in_days = var.log_retention_days

  tags = merge(local.tags, { Service = "vault" })
}

resource "aws_ecs_task_definition" "vault" {
  count = var.enable_vault ? 1 : 0

  family                   = "${local.name}-vault"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  # 256 CPU / 512 MB is the smallest Fargate task there is. Vault is happy
  # there for a single node with a handful of secrets; bump to 512/1024
  # (~$8/mo) if it OOMs or unseal gets sluggish.
  cpu                      = var.vault_cpu
  memory                   = var.vault_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.vault_task[0].arn

  # Graviton, like the services. hashicorp/vault ships a linux/arm64 image.
  runtime_platform {
    cpu_architecture        = var.ecs_cpu_architecture
    operating_system_family = var.ecs_operating_system_family
  }


  volume {
    name = "vault-raft"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.vault[0].id
      root_directory     = "/"
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.vault[0].id
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "vault"
      image     = var.vault_image
      essential = true

      portMappings = [
        {
          containerPort = var.vault_port
          protocol      = "tcp"
        }
      ]

      # docker-entrypoint turns VAULT_LOCAL_CONFIG into the server config.
      environment = [
        {
          name  = "VAULT_LOCAL_CONFIG"
          value = jsonencode({
            storage  = {
              raft = {
                path    = "/vault/raft"
                node_id = "${local.name}-vault-1"
              }
            }
            listener = {
              tcp = {
                address     = "0.0.0.0:${var.vault_port}"
                tls_disable = true # TLS terminates at the ALB (same pattern as the other services)
              }
            }
            seal     = {
              awskms = {
                region     = var.aws_region
                kms_key_id = aws_kms_key.vault.key_id
              }
            }
            api_addr = "https://${var.vault_subdomain}.${var.domain_name}"
            ui       = true
          })
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "vault-raft"
          containerPath = "/vault"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.vault[0].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = merge(local.tags, { Service = "vault" })
}

resource "aws_ecs_service" "vault" {
  count = var.enable_vault ? 1 : 0

  name            = "vault"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.vault[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # One raft node: a failed deploy must roll back, never run two writers.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = var.single_az_ecs ? [aws_subnet.private[0].id] : aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.vault[0].arn
    container_name   = "vault"
    container_port   = var.vault_port
  }

  depends_on = [aws_lb_listener.https]

  tags = merge(local.tags, { Service = "vault" })
}

# -- ALB target group + host-header rule -------------------------------------------

resource "aws_lb_target_group" "vault" {
  count = var.enable_vault ? 1 : 0

  name                 = "${local.name}-vault"
  port                 = var.vault_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    # sealed/uninitialized also count as healthy: Vault needs an operator to
    # init it after the first deploy, and the task shouldn't flap meanwhile.
    path                = "/v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.tags, { Service = "vault" })
}

resource "aws_lb_listener_rule" "vault" {
  count = var.enable_vault ? 1 : 0

  listener_arn = aws_lb_listener.https.arn
  priority     = 10 # service rules use priorities 1..N, Vault stays well clear

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault[0].arn
  }

  condition {
    host_header {
      values = ["${var.vault_subdomain}.${var.domain_name}"]
    }
  }

  tags = merge(local.tags, { Service = "vault" })
}
