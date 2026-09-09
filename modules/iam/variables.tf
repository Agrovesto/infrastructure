variable "name" {
  type = string
}

variable "backup_bucket_arn" {
  description = "S3 bucket ARN for MSSQL backups"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
