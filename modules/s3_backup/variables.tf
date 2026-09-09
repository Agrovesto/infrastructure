variable "name" {
  type = string
}

variable "force_destroy" {
  description = "Allow terraform destroy to empty the bucket (dev only)"
  type        = bool
  default     = true
}

variable "expiration_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
