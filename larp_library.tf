# The Heroku app itself
# resource "heroku_app" "larp_library" {
#   name   = "larp-library"
#   region = "us"
#   stack  = "heroku-20"
#   acm    = true

#   organization {
#     name = "neinteractiveliterature"
#   }

#   config_vars = {
#     ASSETS_HOST                 = "assets.larplibrary.org"
#     RACK_ENV                    = "production"
#     RAILS_ENV                   = "production"
#     RAILS_LOG_TO_STDOUT         = "enabled"
#     RAILS_MAX_THREADS           = "4"
#     RAILS_SERVE_STATIC_FILES    = "enabled"
#     ROLLBAR_CLIENT_ACCESS_TOKEN = rollbar_project_access_token.larp_library_post_client_item.access_token
#   }

#   sensitive_config_vars = {
#     AWS_ACCESS_KEY_ID     = aws_iam_access_key.larp_library.id
#     AWS_REGION            = data.aws_region.current.name
#     AWS_SECRET_ACCESS_KEY = aws_iam_access_key.larp_library.secret
#     AWS_S3_BUCKET         = aws_s3_bucket.larp_library_production.bucket
#     ROLLBAR_ACCESS_TOKEN  = rollbar_project_access_token.larp_library_post_server_item.access_token
#   }
# }

resource "rollbar_project" "larp_library" {
  name = "LarpLibrary"
}

resource "rollbar_project_access_token" "larp_library_post_client_item" {
  project_id = rollbar_project.larp_library.id
  name       = "post_client_item"
  depends_on = [rollbar_project.larp_library]
  scopes     = ["post_client_item"]
}

resource "rollbar_project_access_token" "larp_library_post_server_item" {
  project_id = rollbar_project.larp_library.id
  name       = "post_server_item"
  depends_on = [rollbar_project.larp_library]
  scopes     = ["post_server_item"]
}

resource "aws_s3_bucket" "larp_library_production" {
  acl    = "private"
  bucket = "larp-library-production"

  cors_rule {
    allowed_headers = ["Authorization"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = []
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
    expose_headers  = ["ETag"]
    max_age_seconds = 0
  }
}

resource "aws_iam_group" "larp_library" {
  name = "larp-library"
}

resource "aws_iam_group_policy" "larp_library_s3" {
  name  = "larp-library-s3"
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
    },
    {
      "Sid": "SesAccess",
      "Effect":"Allow",
      "Action":"ses:SendRawEmail",
      "Resource":"*"
    }
  ]
}
  EOF
}

resource "aws_iam_user" "larp_library" {
  name = "larp-library"
}

resource "aws_iam_user_group_membership" "larp_library" {
  user   = aws_iam_user.larp_library.name
  groups = [aws_iam_group.larp_library.name]
}

resource "aws_iam_access_key" "larp_library" {
  user = aws_iam_user.larp_library.name
}

resource "cloudflare_zone" "larplibrary_org" {
  account_id = "9e36b5cabcd5529d3bd08131b7541c06"
  zone       = "larplibrary.org"
}

resource "cloudflare_record" "larplibrary_org_apex_redirect" {
  zone_id = cloudflare_zone.larplibrary_org.id
  name    = "larplibrary.org"
  type    = "A"
  value   = "216.24.57.1"
}

resource "cloudflare_record" "larplibrary_org_spf" {
  zone_id = cloudflare_zone.larplibrary_org.id
  name    = "larplibrary.org"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
}

resource "cloudflare_record" "larplibrary_org_www" {
  zone_id = cloudflare_zone.larplibrary_org.id
  name    = "www.larplibrary.org"
  type    = "CNAME"
  value   = "larp-library.onrender.com"
}

resource "cloudflare_record" "larplibrary_org_mx" {
  zone_id  = cloudflare_zone.larplibrary_org.id
  name     = "larplibrary.org"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "assets_larplibrary_org" {
  zone_id = cloudflare_zone.larplibrary_org.id
  name    = "assets.larplibrary.org"
  type    = "CNAME"
  value   = module.assets_larplibrary_org_cloudfront.cloudfront_distribution.domain_name
}


module "assets_larplibrary_org_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name              = "assets.larplibrary.org"
  origin_id                = "larplibrary"
  origin_domain_name       = "www.larplibrary.org"
  origin_protocol_policy   = "https-only"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  cloudflare_zone          = cloudflare_zone.larplibrary_org
  compress                 = true
}

resource "cloudflare_record" "interactiveliterature_org_library_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "library"
  type    = "CNAME"
  value   = "larp-library.onrender.com"
}
