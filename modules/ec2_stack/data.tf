data "aws_ami" "al2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023[0].id

  nginx_upstreams = concat(
    [
      for k, api in var.apis : {
        name      = k
        subdomain = api.subdomain
        port      = api.host_port
      }
    ],
    [
      {
        name      = "vault"
        subdomain = var.vault.subdomain
        port      = var.vault.host_port
      }
    ]
  )
}
