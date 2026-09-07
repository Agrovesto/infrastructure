output "cluster_name" {
  value = aws_ecs_cluster.this.name
}
output "security_group_ids" {
  value = { for k, sg in aws_security_group.service : k => sg.id }
}
output "admin_security_group_id" {
  value = aws_security_group.admin.id
}
output "admin_task_definition_arn" {
  value = aws_ecs_task_definition.admin.arn
}
output "admin_run_task_input" {
  description = "Non-secret AWS CLI input for a one-off private ECS provisioning task."
  value = {
    cluster    = aws_ecs_cluster.this.name, taskDefinition = aws_ecs_task_definition.admin.arn
    launchType = "FARGATE", platformVersion = "LATEST", count = 1
    networkConfiguration = { awsvpcConfiguration = {
      subnets = var.subnet_ids, securityGroups = [aws_security_group.admin.id], assignPublicIp = "DISABLED"
    } }
  }
}
output "task_definitions" {
  value = { for k, task in aws_ecs_task_definition.service : k => task.arn }
}
output "security" {
  value = {
    running_services = length(aws_ecs_service.this)
    tasks = { for name, task in aws_ecs_task_definition.service : name => {
      network_mode  = task.network_mode
      containers    = jsondecode(task.container_definitions)
      compatibility = task.requires_compatibilities
    } }
    services = { for name, service in aws_ecs_service.this : name => {
      public_ip     = one(service.network_configuration).assign_public_ip
      desired_count = service.desired_count
      rollback      = service.deployment_circuit_breaker[0].rollback
    } }
    execution_policies = { for name, policy in aws_iam_role_policy.execution : name => jsondecode(policy.policy) }
    database_clients   = keys(local.database_services)
  }
}
