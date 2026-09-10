variable "name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "instance_profile_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_id" {
  description = "Leave empty to use latest Amazon Linux 2023"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 key pair name. Optional if using SSM."
  type        = string
  default     = ""
}

variable "root_volume_size_gb" {
  description = "OS + apps disk"
  type        = number
  default     = 50
}

variable "mssql_volume_size_gb" {
  description = "Dedicated MSSQL data disk"
  type        = number
  default     = 50
}

variable "mssql_volume_device" {
  type    = string
  default = "/dev/sdf"
}

variable "associate_elastic_ip" {
  type    = bool
  default = true
}

variable "domain_name" {
  type = string
}

variable "apis" {
  description = "Map of API containers. Add more keys to run additional APIs."
  type = map(object({
    image     = string
    host_port = number
    subdomain = string
    env       = optional(map(string), {})
  }))
}

variable "mssql" {
  description = "MSSQL container and databases"
  type = object({
    sa_password = string
    databases   = list(string)
    image       = optional(string, "mcr.microsoft.com/mssql/server:2022-latest")
    host_port   = optional(number, 1433)
    subdomain   = optional(string, "mssql")
  })
  sensitive = true
}

variable "vault" {
  type = object({
    image     = optional(string, "hashicorp/vault:1.15")
    host_port = optional(number, 8200)
    subdomain = optional(string, "vault")
  })
  default = {
    image     = "hashicorp/vault:1.15"
    host_port = 8200
    subdomain = "vault"
  }
}

variable "backup_bucket" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
