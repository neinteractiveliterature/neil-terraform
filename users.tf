resource "aws_iam_user" "dkapell" {
  name = "dkapell"
}

resource "aws_iam_user_group_membership" "dkapell" {
  user = aws_iam_user.dkapell.name
  groups = [
    aws_iam_group.interactiveliterature_org_admin.name,
    aws_iam_group.ops_admin.name,
    aws_iam_group.terraform_admin.name
  ]
}

resource "aws_iam_user" "eschiffer" {
  name = "eschiffer"
}

resource "aws_iam_user_group_membership" "eschiffer" {
  user = aws_iam_user.eschiffer.name
  groups = [
    aws_iam_group.interactiveliterature_org_admin.name
  ]
}

resource "aws_iam_user" "nbudin" {
  name = "nbudin"
}

resource "aws_iam_user_group_membership" "nbudin" {
  user = aws_iam_user.nbudin.name
  groups = [
    aws_iam_group.interactiveliterature_org_admin.name,
    aws_iam_group.ops_admin.name,
    aws_iam_group.terraform_admin.name
  ]
}

resource "aws_iam_user" "jdiewald" {
  name = "jdiewald"
}

resource "aws_iam_user_group_membership" "jdiewald" {
  user = aws_iam_user.jdiewald.name
  groups = [
    aws_iam_group.interactiveliterature_org_admin.name
  ]
}

resource "aws_iam_user" "neil_wordpress" {
  name = "neil_wordpress"
}

resource "aws_iam_user_policy" "neil_wordpress" {
  user   = aws_iam_user.neil_wordpress.name
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ses:SendRawEmail",
            "Resource": "*"
        },
        {
          "Sid": "bucket",
          "Effect": "Allow",
          "Action": [
            "s3:*"
          ],
          "Resource": [
            "arn:aws:s3:::${aws_s3_bucket.interactiveliterature_org_wordpress_backups.bucket}"
          ]
        },
        {
          "Sid": "objects",
          "Effect": "Allow",
          "Action": [
            "s3:*"
          ],
          "Resource": [
            "arn:aws:s3:::${aws_s3_bucket.interactiveliterature_org_wordpress_backups.bucket}/*"
          ]
        }
    ]
  }
  EOF
}

resource "aws_iam_access_key" "neil_wordpress" {
  user = aws_iam_user.neil_wordpress.name
}

output "neil_wordpress_iam_creds" {
  sensitive = true
  value = {
    aws_access_key_id     = aws_iam_access_key.neil_wordpress.id
    aws_secret_access_key = sensitive(aws_iam_access_key.neil_wordpress.secret)
  }
}

output "neil_wordpress_smtp_url" {
  sensitive = true
  value     = "smtp://${aws_iam_access_key.neil_wordpress.id}:${aws_iam_access_key.neil_wordpress.ses_smtp_password_v4}@email-smtp.us-east-1.amazonaws.com"
}
