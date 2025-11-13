variable "vector_heroku_source_username" {
  type = string
}

variable "vector_heroku_source_password" {
  type = string
}

resource "aws_cloudwatch_log_group" "fly_apps" {
  name = "fly_apps"

  tags = {
    Environment = "production"
  }

  retention_in_days = 30
}

resource "aws_iam_group" "vector" {
  name = "vector"
}

resource "aws_iam_group_policy" "vector" {
  name  = "vector"
  group = aws_iam_group.vector.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudwatchLogsAccess",
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups",
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
  EOF
}

resource "aws_iam_user" "vector" {
  name = "vector"
}

resource "aws_iam_user_group_membership" "vector" {
  user   = aws_iam_user.vector.name
  groups = [aws_iam_group.vector.name]
}

resource "aws_iam_access_key" "vector" {
  user = aws_iam_user.vector.name
}
