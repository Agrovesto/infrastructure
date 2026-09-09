locals {
  docker_compose = templatefile("${path.module}/templates/docker-compose.yml.tftpl", {
    apis          = var.apis
    mssql         = var.mssql
    vault         = var.vault
    backup_bucket = var.backup_bucket
  })

  nginx_conf = templatefile("${path.module}/templates/nginx.conf.tftpl", {
    domain    = var.domain_name
    upstreams = local.nginx_upstreams
  })

  init_sql = join("\n", [
    for db in var.mssql.databases :
    "IF DB_ID(N'${db}') IS NULL CREATE DATABASE [${db}];"
  ])
}

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
    tags                  = merge(var.tags, { Name = "${var.name}-os-apps" })
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    mssql_device    = var.mssql_volume_device
    sa_password     = var.mssql.sa_password
    backup_bucket   = var.backup_bucket
    aws_region      = var.aws_region
    docker_compose  = local.docker_compose
    nginx_conf      = local.nginx_conf
    init_sql        = local.init_sql
    db_list         = join(" ", var.mssql.databases)
  })

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(var.tags, { Name = "${var.name}-app-host" })
}

resource "aws_ebs_volume" "mssql" {
  availability_zone = aws_instance.this.availability_zone
  size              = var.mssql_volume_size_gb
  type              = "gp3"
  encrypted         = true
  tags              = merge(var.tags, { Name = "${var.name}-mssql-data" })
}

resource "aws_volume_attachment" "mssql" {
  device_name = var.mssql_volume_device
  volume_id   = aws_ebs_volume.mssql.id
  instance_id = aws_instance.this.id
}

resource "aws_eip" "this" {
  count  = var.associate_elastic_ip ? 1 : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-eip" })
}

resource "aws_eip_association" "this" {
  count         = var.associate_elastic_ip ? 1 : 0
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this[0].id
}
