resource "aws_iam_group" "terraform_admin" {
  name = "terraform-admin"
}

resource "aws_iam_group_policy" "terraform_admin_s3" {
  group = aws_iam_group.terraform_admin.name
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ],
        "Resource": "arn:aws:s3:::neil-terraform-state"
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Resource": "arn:aws:s3:::neil-terraform-state/*"
      }
    ]
  }
  EOF
}

resource "aws_iam_group_policy" "terraform_admin_dynamodb" {
  group = aws_iam_group.terraform_admin.name
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        "Resource": "arn:aws:dynamodb:*:*:table/terraform_state_locks"
      }
    ]
  }
  EOF
}

resource "aws_iam_group" "ops_admin" {
  name = "ops-admin"
}

resource "aws_iam_group_policy_attachment" "ops_admin_acm" {
  group = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCertificateManagerFullAccess"
}

resource "aws_iam_group_policy_attachment" "ops_admin_cloudfront" {
  group = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/CloudFrontFullAccess"
}

resource "aws_iam_group_policy_attachment" "ops_admin_dynamodb" {
  group = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_group_policy_attachment" "ops_admin_iam" {
  group = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_group_policy_attachment" "ops_admin_kms" {
  group = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser"
}

resource "aws_iam_group_policy_attachment" "ops_admin_lambda" {
  group = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaFullAccess"
}

resource "aws_iam_group_policy_attachment" "ops_admin_rds" {
  group = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

resource "aws_iam_group_policy_attachment" "ops_admin_route53" {
  group = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

resource "aws_iam_group_policy_attachment" "ops_admin_s3" {
  group = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_group_policy_attachment" "ops_admin_sqs" {
  group = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}
