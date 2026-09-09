variable "zone_name" {
  type = string
}
variable "existing_zone_id" {
  description = "Use an existing public zone without taking ownership; null creates a managed zone (or permits import)."
  type        = string
  default     = null
}
variable "records" {
  description = "Additional simple records to create/import. Names are fully qualified; do not duplicate managed service or ACM records."
  type = map(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    records = list(string)
  }))
  default = {}
}
variable "aliases" {
  type = map(object({
    name                   = string
    type                   = optional(string, "A")
    target_name            = string
    target_zone_id         = string
    evaluate_target_health = optional(bool, false)
  }))
  default = {}
}
