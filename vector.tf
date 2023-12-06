variable "vector_heroku_source_username" {
  type = string
}

variable "vector_heroku_source_password" {
  type = string
}

resource "heroku_app" "neil_vector" {
  name   = "neil-vector"
  region = "us"
  stack  = "container"

  organization {
    name = "neinteractiveliterature"
  }

  config_vars = {
  }

  sensitive_config_vars = {
    AWS_ACCESS_KEY_ID      = aws_iam_access_key.vector.id
    AWS_SECRET_ACCESS_KEY  = aws_iam_access_key.vector.secret
    HEROKU_SOURCE_USERNAME = var.vector_heroku_source_username
    HEROKU_SOURCE_PASSWORD = var.vector_heroku_source_password
  }
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
