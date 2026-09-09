variable "apps" {
  description = "Map of Amplify applications to create. Add more keys to grow."
  type = map(object({
    repository               = string
    branch                   = optional(string, "main")
    subdomain                = string
    framework                = optional(string, "React")
    build_spec               = optional(string)
    environment_variables    = optional(map(string), {})
    # Auto-build the tracked branch (branch above) on push - keeps deploys working.
    enable_auto_build        = optional(bool, true)
    # Auto-build arbitrary new branches too - off by default so feature
    # branches don't consume billable Amplify build minutes.
    enable_branch_auto_build = optional(bool, false)
  }))
}

variable "github_access_token" {
  description = "GitHub PAT for Amplify source. Leave empty to skip connecting a repo."
  type        = string
  default     = ""
  sensitive   = true
}

variable "domain_name" {
  description = "Root domain (e.g. agrovesto.dev)"
  type        = string
}

variable "enable_custom_domain" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
