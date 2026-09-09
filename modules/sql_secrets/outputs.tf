output "secret_arns" {
  value = { for k, secret in aws_secretsmanager_secret.database : k => secret.arn }
}
