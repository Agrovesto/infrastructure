resource "aws_iam_instance_profile" "tfer--agx-api-asgInstanceProfile" {
  name = "agx-api-asgInstanceProfile"
  path = "/"
  role = "ec2_role"
}

resource "aws_iam_instance_profile" "tfer--noma-api-asgInstanceProfile" {
  name = "noma-api-asgInstanceProfile"
  path = "/"
  role = "ec2_role"
}

resource "aws_iam_instance_profile" "tfer--nomaos-asgInstanceProfile" {
  name = "nomaos-asgInstanceProfile"
  path = "/"
  role = "ec2_role-12c63a"
}

resource "aws_iam_instance_profile" "tfer--ssmrole" {
  name = "ssmrole"
  path = "/"
  role = "ssmrole"
}
