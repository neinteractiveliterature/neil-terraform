resource "aws_iam_group" "terraform_admin" {
  name = "terraform-admin"
}

resource "aws_iam_group_policy" "terraform_admin" {
  group  = aws_iam_group.terraform_admin.name
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
      },
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

resource "aws_iam_group_policy_attachment" "ops_admin_administrator_access" {
  group      = aws_iam_group.ops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
