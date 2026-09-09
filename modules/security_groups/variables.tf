variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH to the EC2 instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
