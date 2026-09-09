variable "domain_name" {
  description = "Root domain. Zone is created if create_zone is true."
  type        = string
}

variable "create_zone" {
  type    = bool
  default = true
}

variable "existing_zone_id" {
  description = "Use an existing hosted zone instead of creating one"
  type        = string
  default     = ""
}

variable "a_records" {
  description = "Simple A records (name => ipv4). Use empty name for apex."
  type        = map(string)
  default     = {}
}

variable "cname_records" {
  description = "CNAME records (name => target)"
  type        = map(string)
  default     = {}
}

variable "alias_records" {
  description = "Alias A records (name => {name, zone_id, evaluate_target_health})"
  type = map(object({
    name                   = string
    zone_id                = string
    evaluate_target_health = optional(bool, false)
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
