variable "larp_library_production_db_password" {
  type = string
}

variable "larp_library_intercode_app_id" {
  type = string
}

variable "larp_library_intercode_app_secret" {
  type = string
}

variable "larp_library_secret_key_base" {
  type = string
}

locals {
  larp_library_domains = toset([
    "library.interactiveliterature.org",
    "www.larplibrary.org"
  ])

  larp_library_cors_allowed_origins = [for domain in local.larp_library_domains : "https://${domain}"]
}

# The Heroku app itself
# resource "heroku_app" "larp_library" {
#   name   = "larp-library"
#   region = "us"
#   stack  = "container"
#   acm    = true

#   organization {
#     name = "neinteractiveliterature"
#   }

#   config_vars = {
#     ASSETS_HOST                 = "assets.larplibrary.org"
#     CLOUDWATCH_LOG_GROUP        = aws_cloudwatch_log_group.larp_library_production.name
#     INTERCODE_URL               = "https://www.neilhosting.net"
#     LANG                        = "en"
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
#     DATABASE_URL          = "postgres://larp_library_production:${var.larp_library_production_db_password}@${aws_db_instance.neil_production.endpoint}/larp_library_production?sslrootcert=rds-global-bundle.pem"
#     INTERCODE_APP_ID      = var.larp_library_intercode_app_id
#     INTERCODE_APP_SECRET  = var.larp_library_intercode_app_secret
#     ROLLBAR_ACCESS_TOKEN  = rollbar_project_access_token.larp_library_post_server_item.access_token
#     SECRET_KEY_BASE       = var.larp_library_secret_key_base
#   }
# }

# resource "heroku_drain" "larp_library_vector" {
#   app_id = heroku_app.larp_library.id
#   url    = "https://${var.vector_heroku_source_username}:${var.vector_heroku_source_password}@vector.interactiveliterature.org/events?application=larp-library"
# }

# resource "heroku_domain" "larp_library" {
#   for_each = local.larp_library_domains

#   app_id   = heroku_app.larp_library.uuid
#   hostname = each.value
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
  bucket = "larp-library-production"
}

resource "aws_s3_bucket_acl" "larp_library_production" {
  bucket = aws_s3_bucket.larp_library_production.bucket
  acl    = "private"
}

resource "aws_s3_bucket_cors_configuration" "larp_library_production" {
  bucket = aws_s3_bucket.larp_library_production.bucket

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
    allowed_origins = concat(
      ["https://larp-library.herokuapp.com"],
      local.larp_library_cors_allowed_origins
    )
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
    },
    {
      "Sid": "CloudwatchLogsAccess",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:PutLogEvents"
      ],
      "Resource": "${aws_cloudwatch_log_group.larp_library_production.arn}:*"
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

resource "aws_cloudwatch_log_group" "larp_library_production" {
  name = "larp_library_production"

  tags = {
    Environment = "production"
    Application = "larp_library"
  }

  retention_in_days = 30
}

resource "cloudflare_zone" "larplibrary_org" {
  account = {
    id = "9e36b5cabcd5529d3bd08131b7541c06"
  }
  name = "larplibrary.org"
}

module "larplibrary_org_apex_redirect" {
  source = "./modules/cloudflare_apex_redirect"

  cloudflare_zone               = cloudflare_zone.larplibrary_org
  domain_name                   = "larplibrary.org"
  redirect_destination_hostname = "www.larplibrary.org"
  redirect_destination_path     = "/"
  redirect_destination_protocol = "https"
  alternative_names             = []
}

resource "cloudflare_dns_record" "larplibrary_org_spf" {
  zone_id = cloudflare_zone.larplibrary_org.id
  name    = "larplibrary.org"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  ttl     = 1
}

resource "cloudflare_dns_record" "larplibrary_org_www" {
  zone_id = cloudflare_zone.larplibrary_org.id
  name    = "www.larplibrary.org"
  type    = "CNAME"
  content = "larp-library.fly.dev"
  ttl     = 1
}

module "larplibrary_org_forwardemail_receiving_domain" {
  source = "./modules/forwardemail_receiving_domain"

  cloudflare_zone   = cloudflare_zone.larplibrary_org
  name              = "larplibrary.org"
  verification_code = local.forwardemail_verification_records_by_domain["larplibrary.org"]
}

resource "cloudflare_dns_record" "assets_larplibrary_org" {
  zone_id = cloudflare_zone.larplibrary_org.id
  name    = "assets.larplibrary.org"
  type    = "CNAME"
  content = module.assets_larplibrary_org_cloudfront.cloudfront_distribution.domain_name
  ttl     = 1
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

resource "cloudflare_dns_record" "interactiveliterature_org_library_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "library.interactiveliterature.org"
  type    = "CNAME"
  content = "larp-library.fly.dev"
  ttl     = 1
}

resource "github_repository" "larp_library" {
  name        = "larp_library"
  description = "A site for hosting free-to-run larps"

  delete_branch_on_merge = true
  has_downloads          = true
  has_issues             = true
  has_projects           = true
  has_wiki               = true
  vulnerability_alerts   = true
}

resource "github_actions_secret" "larp_library_fly_api_token" {
  repository      = github_repository.larp_library.id
  secret_name     = "FLY_API_TOKEN"
  plaintext_value = var.fly_gha_api_token
}
