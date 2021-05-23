# The Heroku app itself
resource "heroku_app" "larp_library" {
  name = "larp-library"
  region = "us"
  stack = "heroku-20"
  acm = true

  organization {
    name = "neinteractiveliterature"
  }

  config_vars = {
    ASSETS_HOST = "assets.larplibrary.org"
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
  user = aws_iam_user.larp_library.name
  groups = [aws_iam_group.larp_library.name]
}

resource "aws_iam_access_key" "larp_library" {
  user = aws_iam_user.larp_library.name
}

resource "aws_route53_zone" "larplibrary_org" {
  name = "larplibrary.org"
}

module "larp_library_apex_redirect" {
  source = "./modules/cloudfront_apex_redirect"

  route53_zone = aws_route53_zone.larplibrary_org
  redirect_destination = "https://www.larplibrary.org"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}

resource "aws_route53_record" "larplibrary_org_mailgun_tracking" {
  zone_id = aws_route53_zone.larplibrary_org.zone_id
  name = "email.larplibrary.org"
  type = "CNAME"
  ttl = 300
  records = ["mailgun.org."]
}

resource "aws_route53_record" "larplibrary_org_mailgun_dkim" {
  zone_id = aws_route53_zone.larplibrary_org.zone_id
  name = "k1._domainkey.larplibrary.org"
  type = "TXT"
  ttl = 300
  records = ["k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDCeP+37KkcS1+URn+wS0QO31fQ+wcr14rDE2aw8aBhOCEattT3FKCeh60XJsD0flBV0GD/sJA9FM3Fz2Djk5+9kLd5/wQ4lPnO79Y8hRTq3M7nN/k31WNzMPrc75AcOkbIBk5CAuxeQMaPgNG0yTsms3ACRyzAEX0iHQpFyB3WBwIDAQAB"]
}

resource "aws_route53_record" "larplibrary_org_spf" {
  zone_id = aws_route53_zone.larplibrary_org.zone_id
  name = "larplibrary.org"
  type = "TXT"
  ttl = 300
  records = ["v=spf1 include:mailgun.org include:amazonses.com ~all"]
}

resource "aws_route53_record" "larplibrary_org_www" {
  zone_id = aws_route53_zone.larplibrary_org.zone_id
  name = "www.larplibrary.org"
  type = "CNAME"
  ttl = 300
  records = ["www.larplibrary.org.herokudns.com."]
}

resource "aws_route53_record" "larplibrary_org_mx" {
  zone_id = aws_route53_zone.larplibrary_org.zone_id
  name = "larplibrary.org"
  type = "MX"
  ttl = 300
  records = [
    "10 inbound-smtp.us-east-1.amazonaws.com.",
  ]
}

resource "aws_route53_record" "assets_larplibrary_org" {
  zone_id = aws_route53_zone.larplibrary_org.zone_id
  name = "assets.larplibrary.org"
  type = "CNAME"
  ttl = 300
  records = ["${module.assets_larplibrary_org_cloudfront.cloudfront_distribution.domain_name}."]
}

module "assets_larplibrary_org_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name = "assets.larplibrary.org"
  origin_id = "larplibrary"
  origin_domain_name = "www.larplibrary.org"
  origin_protocol_policy = "https-only"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  route53_zone = aws_route53_zone.larplibrary_org
}
