resource "aws_iam_group" "rotator_production" {
  name = "rotator-production"
}

resource "aws_iam_group_policy" "rotator_production" {
  name  = "rotator-production"
  group = aws_iam_group.rotator_production.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ses:SendRawEmail",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_user" "rotator_production" {
  name = "rotator-production"
}

resource "aws_iam_user_group_membership" "rotator_production" {
  user   = aws_iam_user.rotator_production.name
  groups = [aws_iam_group.rotator_production.name]
}

resource "aws_iam_access_key" "rotator_production" {
  user = aws_iam_user.rotator_production.name
}
