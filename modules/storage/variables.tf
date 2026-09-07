variable "name" {
  type = string
}
variable "kms_key_arn" {
  type    = string
  default = null
}
variable "access_log_bucket" {
  type    = string
  default = null
}
variable "additional_policy_json" {
  type    = string
  default = null
}
variable "expiration_days" {
  type    = number
  default = 0
}
variable "noncurrent_days" {
  type    = number
  default = 90
}
variable "object_lock_days" {
  type    = number
  default = 0
}

variable "enable_access_logging" {
  description = "Explicit boolean: do not base resource count on a bucket ID that is unknown during the first plan."
  type        = bool
  default     = true
}
