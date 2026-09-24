resource "aws_iam_instance_profile" "tfer--CloudWatchAgentServerPolicy" {
  name = "CloudWatchAgentServerPolicy"
  path = "/"
  role = "CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "tfer--agx-apiInstanceProfile" {
  name = "agx-apiInstanceProfile"
  path = "/"
  role = "ec2_role-d0f2b8"
}

resource "aws_iam_instance_profile" "tfer--instanceRole" {
  name = "instanceRole"
  path = "/"
  role = "instanceRole"
}

resource "aws_iam_instance_profile" "tfer--instanceRole-profile" {
  name = "instanceRole-profile"
  path = "/"
  role = "instanceRole"
}

resource "aws_iam_instance_profile" "tfer--noma-apiInstanceProfile" {
  name = "noma-apiInstanceProfile"
  path = "/"
  role = "ec2_role-d0f2b8"
}
