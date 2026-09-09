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
      {
        name      = onboarding
        subdomain = onboarding-subdomain
        port      = onboarding.host_port
      }
    ],
        [
      {
        name      = wallet
        subdomain = wallet-subdomain
        port      = wallet.host_port
      }
    ],    [
      {
        name      = input
        subdomain = input-subdomain
        port      = input.host_port
      }
    ],    [
      {
        name      = moneval
        subdomain = moneval-subdomain
        port      = moneval.host_port
      }
    ],    [
      {
        name      = serviceprovider
        subdomain = serviceprovider-subdomain
        port      = serviceprovider.host_port
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
