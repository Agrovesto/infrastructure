variable "name" {
  type = string
}
variable "cidr" {
  type = string
  validation {
    condition     = can(cidrsubnet(var.cidr, 8, 22))
    error_message = "Use an IPv4 VPC CIDR with room for public, app and isolated DB subnets (normally /16)."
  }
}
variable "availability_zones" {
  type = list(string)
  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "Provide exactly two different availability zones in the configured region."
  }
}
variable "single_nat_gateway" {
  type = bool
}
variable "kms_key_arn" {
  type = string
}
variable "log_retention_days" {
  type = number
}
variable "permissions_boundary_arn" {
  type = string
}

variable "region" {
  type = string
}

variable "enable_interface_endpoints" {
  description = "When true, create Interface VPC Endpoints for ECR, CloudWatch, Secrets Manager and SSM. Bypasses NAT data-processing charges at ~$0.01/hr/AZ/endpoint. Recommended for prod; leave false for cost-sensitive dev."
  type        = bool
  default     = false
}
