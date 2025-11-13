variable "listmonk_production_db_password" {
  type = string
}

variable "listmonk_app_admin_password" {
  type = string
}

# resource "heroku_app" "listmonk" {
#   name   = "neil-listmonk"
#   region = "us"
#   stack  = "container"

#   organization {
#     name = "neinteractiveliterature"
#   }

#   config_vars = {
#   }

#   sensitive_config_vars = {
#     LISTMONK_app__admin_username = "neiladmin"
#     LISTMONK_app__admin_password = var.listmonk_app_admin_password
#     LISTMONK_db__host            = aws_db_instance.neil_production.address
#     LISTMONK_db__user            = "listmonk_production"
#     LISTMONK_db__password        = var.listmonk_production_db_password
#     LISTMONK_db__database        = "listmonk_production"
#     LISTMONK_db__ssl_mode        = "require"
#   }
# }

# resource "heroku_drain" "listmonk_vector" {
#   app_id = heroku_app.listmonk.id
#   url    = "https://${var.vector_heroku_source_username}:${var.vector_heroku_source_password}@vector.interactiveliterature.org/events?application=neil-listmonk"
# }

# resource "heroku_domain" "listmonk_interactiveliterature_org" {
#   app_id   = heroku_app.listmonk.uuid
#   hostname = "listmonk.interactiveliterature.org"
# }

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
