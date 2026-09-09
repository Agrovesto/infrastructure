variable "name" {
  type = string
}

variable "instance_id" {
  type = string
}

variable "scheduler_role_arn" {
  type = string
}

variable "timezone" {
  type    = string
  default = "Africa/Lagos"
}

variable "start_cron" {
  description = "EventBridge Scheduler cron (6 fields) to start the instance"
  type        = string
  default     = "cron(0 8 ? * MON-FRI *)"
}

variable "stop_cron" {
  description = "EventBridge Scheduler cron (6 fields) to stop the instance"
  type        = string
  default     = "cron(0 20 ? * MON-FRI *)"
}

variable "enabled" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
