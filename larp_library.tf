# The Heroku app itself
resource "heroku_app" "larp_library" {
  name = "larp-library"
  region = "us"
  stack = "heroku-18"
  acm = true

  organization {
    name = "neinteractiveliterature"
  }

  config_vars = {
    RACK_ENV = "production"
    RAILS_ENV = "production"
    RAILS_LOG_TO_STDOUT = "enabled"
    RAILS_MAX_THREADS = "4"
    RAILS_SERVE_STATIC_FILES = "enabled"
  }

  sensitive_config_vars = {
    AWS_ACCESS_KEY_ID = aws_iam_access_key.larp_library.id
    AWS_REGION = data.aws_region.current.name
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.larp_library.secret
    AWS_S3_BUCKET = aws_s3_bucket.larp_library_production.bucket
  }
}

resource "aws_s3_bucket" "larp_library_production" {
  acl    = "private"
  bucket = "larp-library-production"

  cors_rule {
    allowed_headers = ["Authorization"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers = []
    max_age_seconds = 3000
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "DELETE", "GET"]
    allowed_origins = [
      "https://library.interactiveliterature.org",
      "https://larp-library.herokuapp.com",
      "https://www.larplibrary.org"
    ]
    expose_headers = ["ETag"]
    max_age_seconds = 0
  }
}

resource "aws_iam_group" "larp_library" {
  name = "larp-library"
}

resource "aws_iam_group_policy" "larp_library_s3" {
  name = "larp-library-s3"
  group = aws_iam_group.larp_library.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BackupFolderAccess",
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
        "arn:aws:s3:::${aws_s3_bucket.larp_library_production.bucket}/*"
      ]
    },
    {
      "Sid": "BucketLevelAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListAllMyBuckets",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::*"
      ]
    }
  ]
}
  EOF
}

resource "aws_iam_user" "larp_library" {
  name = "larp-library"
}

resource "aws_iam_user_group_membership" "larp_library" {
  user = aws_iam_user.larp_library.name
  groups = [aws_iam_group.larp_library.name]
}

resource "aws_iam_access_key" "larp_library" {
  user = aws_iam_user.larp_library.name
}
