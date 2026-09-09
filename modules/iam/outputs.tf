output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2.name
}

output "scheduler_role_arn" {
  value = aws_iam_role.scheduler.arn
}