# =============================================================================
# EC2 app host — nginx reverse proxy + docker compose stack
# (5 APIs, HashiCorp Vault, SQL Server 2022)
# =============================================================================

resource "aws_instance" "app" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  ebs_optimized               = true
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = false
  key_name                    = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(local.tags, { Name = "${local.name}-os-apps" })
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    mssql_device   = var.mssql_volume_device
    sa_password    = var.mssql_sa_password
    backup_bucket  = aws_s3_bucket.backup.bucket
    aws_region     = var.aws_region
    ecr_registry   = local.ecr_registry
    docker_compose = local.docker_compose
    nginx_conf     = local.nginx_conf
    init_sql       = local.init_sql
    db_list        = join(" ", var.mssql_databases)
  })

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(local.tags, { Name = "${local.name}-app-host" })
}

resource "aws_ebs_volume" "mssql" {
  availability_zone = aws_instance.app.availability_zone
  size              = var.mssql_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(local.tags, { Name = "${local.name}-mssql-data" })
}

resource "aws_volume_attachment" "mssql" {
  device_name = var.mssql_volume_device
  volume_id   = aws_ebs_volume.mssql.id
  instance_id = aws_instance.app.id
}

resource "aws_eip" "app" {
  #checkov:skip=CKV2_AWS_19: EIP is attached to the EC2 host via aws_eip_association below (checkov does not follow that resource)
  count  = var.associate_elastic_ip ? 1 : 0
  domain = "vpc"

  tags = merge(local.tags, { Name = "${local.name}-eip" })
}

resource "aws_eip_association" "app" {
  count = var.associate_elastic_ip ? 1 : 0

  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app[0].id
}
