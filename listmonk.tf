resource "aws_s3_bucket" "listmonk_production" {
  bucket = "neil-listmonk-production"
}

resource "aws_iam_group" "listmonk_production" {
  name = "listmonk-production"
}

resource "aws_iam_group_policy" "listmonk_production" {
  name  = "listmonk-production"
  group = aws_iam_group.listmonk_production.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListmonkS3Access",
      "Effect": "Allow",
      "Action": [
        "s3:GetObjectVersion",
        "s3:DeleteObjectVersion",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:RestoreObject"
      ],
      "Resource": [
        "${aws_s3_bucket.listmonk_production.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "ses:SendRawEmail",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_user" "listmonk_production" {
  name = "listmonk-production"
}

resource "aws_iam_user_group_membership" "listmonk_production" {
  user   = aws_iam_user.listmonk_production.name
  groups = [aws_iam_group.listmonk_production.name]
}

resource "aws_iam_access_key" "listmonk_production" {
  user = aws_iam_user.listmonk_production.name
}
