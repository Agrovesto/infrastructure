variable "name" {
  type = string
}
variable "zone_name" {
  type = string
}
variable "frontends" {
  description = "Static Amplify Hosting apps. Deploy built ZIPs with publish-amplify.sh; no GitHub token in Terraform/state."
  type = map(object({
    branch_name           = optional(string, "dev")
    domain_prefix         = optional(string)
    environment_variables = optional(map(string), {})
    spa                   = optional(bool, true)
  }))
}
variable "zone_id" {
  type = string
}
