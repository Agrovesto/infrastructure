# =============================================================================
# IAM — EC2 host role (MSSQL backups, the boot-time config read, SSM) and the
# scheduler role. No CloudWatch Logs grants and no log driver anywhere in this
# stack: the app logs are collected on the host itself (dev/logging.tf).
# =============================================================================

resource "aws_iam_role" "ec2" {
  name               = "${local.name}-ec2-role"
  assume_role_policy = can(jsondecode(data.aws_iam_policy_document.ec2_assume.json)) ? data.aws_iam_policy_document.ec2_assume.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"

  tags = local.tags
}

resource "aws_iam_role_policy" "ec2" {
  name   = "${local.name}-ec2-policy"
  role   = aws_iam_role.ec2.id
  policy = can(jsondecode(data.aws_iam_policy_document.ec2.json)) ? data.aws_iam_policy_document.ec2.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = local.tags
}

resource "aws_iam_role" "scheduler" {
  name               = "${local.name}-ec2-scheduler-role"
  assume_role_policy = can(jsondecode(data.aws_iam_policy_document.scheduler_assume.json)) ? data.aws_iam_policy_document.scheduler_assume.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"

  tags = local.tags
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "${local.name}-scheduler-policy"
  role   = aws_iam_role.scheduler.id
  policy = can(jsondecode(data.aws_iam_policy_document.scheduler.json)) ? data.aws_iam_policy_document.scheduler.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
}
