# =============================================================================
# DEV — EC2 app host (nginx + docker compose: 5 APIs, Vault, SQL Server)
#
# Run with:  terraform -chdir=dev init && terraform -chdir=dev test
# =============================================================================

mock_provider "aws" {}

override_data {
  target = data.aws_availability_zones.available
  values = {
    names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  }
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:root"
  }
}

override_data {
  target = data.aws_ami.ubuntu
  values = {
    id = "ami-0123456789abcdef0"
  }
}

override_data {
  target = data.aws_iam_policy_document.ec2_assume
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.ec2
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.scheduler_assume
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"scheduler.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.scheduler
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

variables {
  ami_id            = "ami-0123456789abcdef0"
  domain_name       = "nomaos.com"
  mssql_sa_password = "Str0ng!TestOnly"
  mssql_databases   = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]
  instance_type     = "t3.medium"

  apis = {
    wallet = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5001
      subdomain = "dev-wallet-api"
    }
    onboarding = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5002
      subdomain = "dev-onboarding-api"
    }
    input = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5003
      subdomain = "dev-input-api"
    }
    moneval = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5004
      subdomain = "dev-moneval-api"
    }
    serviceprovider = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5005
      subdomain = "dev-serviceprovider-api"
    }
  }

  amplify_apps = {
    landing = {
      repository = "https://github.com/Agrovesto/nomaos-landingpage"
      branch     = "dev"
      subdomain  = "dev-agrovesto"
      framework  = "React"
    }
    onboarding = {
      repository = "https://github.com/Agrovesto/onboarding-frontend"
      branch     = "dev"
      subdomain  = "onboarding-dev"
      framework  = "React"
    }
  }
}

# -----------------------------------------------------------------------------
# Instance
# -----------------------------------------------------------------------------

run "instance" {
  command = apply

  assert {
    condition     = aws_instance.app.instance_type == "t3.medium"
    error_message = "The dev host runs on t3.medium (2 vCPU / 4 GiB)."
  }

  assert {
    condition     = aws_instance.app.associate_public_ip_address == false
    error_message = "The host uses an Elastic IP, not an auto-assigned public IP."
  }

  assert {
    condition     = [for m in aws_instance.app.metadata_options : m.http_tokens] == ["required"]
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = aws_instance.app.tags["Project"] == var.project && aws_instance.app.tags["Environment"] == var.environment
    error_message = "Every resource must carry the Project/Environment tags."
  }
}

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------

run "storage" {
  command = apply

  assert {
    condition     = [for b in aws_instance.app.root_block_device : b.volume_size] == [50]
    error_message = "Root volume is 50 GB."
  }

  assert {
    condition     = [for b in aws_instance.app.root_block_device : b.volume_type] == ["gp3"]
    error_message = "Root volume is gp3."
  }

  assert {
    condition     = [for b in aws_instance.app.root_block_device : b.encrypted] == [true]
    error_message = "The root volume must be encrypted."
  }

  assert {
    condition     = [for b in aws_instance.app.root_block_device : b.delete_on_termination] == [true]
    error_message = "The root volume follows the instance lifecycle."
  }

  assert {
    condition     = aws_ebs_volume.mssql.size == 50
    error_message = "SQL Server data volume is 50 GB."
  }

  assert {
    condition     = aws_ebs_volume.mssql.encrypted == true
    error_message = "The SQL Server data volume must be encrypted."
  }

  assert {
    condition     = aws_ebs_volume.mssql.type == "gp3"
    error_message = "The SQL Server data volume is gp3."
  }
}

# -----------------------------------------------------------------------------
# Elastic IP
# -----------------------------------------------------------------------------

run "elastic_ip" {
  command = apply

  assert {
    condition     = length(aws_eip.app) == 1
    error_message = "associate_elastic_ip = true attaches a stable Elastic IP for DNS."
  }

  assert {
    condition     = length(aws_eip_association.app) == 1
    error_message = "The Elastic IP must be associated with the instance."
  }
}

run "no_elastic_ip" {
  command = apply

  variables {
    associate_elastic_ip = false
  }

  assert {
    condition     = length(aws_eip.app) == 0
    error_message = "associate_elastic_ip = false must not allocate an Elastic IP."
  }
}

# -----------------------------------------------------------------------------
# SQL Server edition on the dev host
# -----------------------------------------------------------------------------

run "mssql_edition" {
  command = apply

  assert {
    condition     = strcontains(aws_instance.app.user_data, "MSSQL_PID: \"Developer\"")
    error_message = "dev runs SQL Server Developer Edition: free, full Enterprise feature set, dev/test use only."
  }
}

run "mssql_edition_overridable" {
  command = apply

  variables {
    mssql_pid = "Express"
  }

  assert {
    condition     = strcontains(aws_instance.app.user_data, "MSSQL_PID: \"Express\"")
    error_message = "var.mssql_pid must reach the compose file (set it to Express when dev must mirror prod's 10 GB cap)."
  }
}
