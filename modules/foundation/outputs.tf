output "kms_key_arn" {
  value = aws_kms_key.this.arn
}
output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
output "access_log_bucket" {
  value = module.access_logs.id
}
