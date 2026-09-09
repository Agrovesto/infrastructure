variable "project" {
  type = string
}
variable "environment" {
  type = string
}
variable "kms_key_arn" {
  type = string
}
variable "databases" {
  description = "Map of stable database keys to SQL database names, one runtime login per database."
  type        = map(string)
  validation {
    condition = alltrue([for k, v in var.databases :
      k != "admin" && can(regex("^[a-z][a-z0-9_]{0,29}$", k)) && can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", v)) && !contains(["master", "model", "msdb", "tempdb", "rdsadmin"], lower(v))
    ]) && length(distinct([for v in values(var.databases) : lower(v)])) == length(var.databases)
    error_message = "Use unique non-system database identifiers and keys of up to 30 lowercase alphanumeric/underscore characters."
  }
}
