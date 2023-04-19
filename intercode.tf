variable "intercode_cloudflare_account_id" {
  type = string
}

variable "intercode_cloudflare_token" {
  type = string
}

variable "intercode_production_db_password" {
  type = string
}

variable "intercode_heroku_api_token" {
  type = string
}

variable "intercode_openid_connect_signing_key" {
  type = string
}

variable "intercode_recaptcha_secret_key" {
  type = string
}

variable "intercode_recaptcha_site_key" {
  type = string
}

variable "intercode_secret_key_base" {
  type = string
}

variable "intercode_stripe_connect_endpoint_secret" {
  type = string
}

variable "intercode_stripe_publishable_key" {
  type = string
}

variable "intercode_stripe_secret_key" {
  type = string
}

variable "intercode_twilio_account_sid" {
  type = string
}

variable "intercode_twilio_auth_token" {
  type = string
}

variable "rds_neiladmin_password" {
  type = string
}

locals {
  intercode_domains = toset([
    "*.beconlarp.com",
    "*.neilhosting.net",
    "*.aegames.org",
    "*.demo.concentral.net",
    "*.gbls.concentral.net",
    "*.festivalofthelarps.com",
    "*.extraconlarp.org",
    "neilhosting.net",
    "www.neilhosting.net",
    "5pi-con.natbudin.com",
    "*.concentral.net",
    "*.interactiveliterature.org",
    "signups.greaterbostonlarpsociety.org",
    "*.interconlarp.org"
  ])
}

# # The Heroku app itself
resource "heroku_app" "intercode" {
  name   = "intercode"
  region = "us"
  stack  = "container"

  organization {
    name = "neinteractiveliterature"
  }

  # we do our own cert management shenanigans using scheduled jobs
  acm = false

  config_vars = {
    ASSETS_HOST                         = "assets.neilhosting.net"
    CLOUDWATCH_LOG_GROUP                = aws_cloudwatch_log_group.intercode2_production.name
    HEROKU_APP_NAME                     = "intercode"
    INTERCODE_CERTS_NO_WILDCARD_DOMAINS = "5pi-con.natbudin.com signups.greaterbostonlarpsociety.org"
    INTERCODE_HOST                      = "neilhosting.net"
    MALLOC_ARENA_MAX                    = 2
    RACK_ENV                            = "production"
    RAILS_ENV                           = "production"
    RAILS_GROUPS                        = "skylight"
    RAILS_LOG_TO_STDOUT                 = "enabled"
    RAILS_MAX_THREADS                   = "3"
    RAILS_SERVE_STATIC_FILES            = "enabled"
    ROLLBAR_CLIENT_ACCESS_TOKEN         = rollbar_project_access_token.intercode_post_client_item.access_token
    ROLLBAR_PUBLIC_PATH                 = "//neilhosting.net/packs"
    RUBY_YJIT_ENABLE                    = "1"
    TWILIO_SMS_NUMBER                   = "+14156345010"
    UPLOADS_HOST                        = "https://uploads.neilhosting.net"
    WEB_CONCURRENCY                     = "0"
  }

  sensitive_config_vars = {
    AWS_ACCESS_KEY_ID              = aws_iam_access_key.intercode2_production.id
    AWS_REGION                     = data.aws_region.current.name
    AWS_SECRET_ACCESS_KEY          = aws_iam_access_key.intercode2_production.secret
    AWS_S3_BUCKET                  = aws_s3_bucket.intercode2_production.bucket
    CF_Account_ID                  = var.intercode_cloudflare_account_id
    CF_Token                       = var.intercode_cloudflare_token
    DATABASE_URL                   = "postgres://intercode_production:${var.intercode_production_db_password}@${aws_db_instance.neil_production.endpoint}/intercode_production?sslrootcert=rds-combined-ca-bundle-2019.pem"
    HEROKU_API_TOKEN               = var.intercode_heroku_api_token
    OPENID_CONNECT_SIGNING_KEY     = var.intercode_openid_connect_signing_key
    RECAPTCHA_SECRET_KEY           = var.intercode_recaptcha_secret_key
    RECAPTCHA_SITE_KEY             = var.intercode_recaptcha_site_key
    ROLLBAR_ACCESS_TOKEN           = rollbar_project_access_token.intercode_post_server_item.access_token
    SECRET_KEY_BASE                = var.intercode_secret_key_base
    STRIPE_CONNECT_ENDPOINT_SECRET = var.intercode_stripe_connect_endpoint_secret
    STRIPE_PUBLISHABLE_KEY         = var.intercode_stripe_publishable_key
    STRIPE_SECRET_KEY              = var.intercode_stripe_secret_key
    TWILIO_ACCOUNT_SID             = var.intercode_twilio_account_sid
    TWILIO_AUTH_TOKEN              = var.intercode_twilio_auth_token
  }
}

resource "heroku_domain" "intercode" {
  for_each = local.intercode_domains

  app_id          = heroku_app.intercode.uuid
  hostname        = each.value
  sni_endpoint_id = "8b295f16-5ffb-4a02-831c-eac6a080a342"
}

resource "heroku_addon" "intercode_memcachedcloud" {
  app_id = heroku_app.intercode.uuid
  plan   = "memcachedcloud:30"
}

resource "heroku_addon" "intercode_papertrail" {
  app_id = heroku_app.intercode.uuid
  plan   = "papertrail:choklad"
}

resource "rollbar_project" "intercode" {
  name = "intercode"
}

resource "rollbar_project_access_token" "intercode_post_client_item" {
  project_id = rollbar_project.intercode.id
  name       = "post_client_item"
  depends_on = [rollbar_project.intercode]
  scopes     = ["post_client_item"]
}

resource "rollbar_project_access_token" "intercode_post_server_item" {
  project_id = rollbar_project.intercode.id
  name       = "post_server_item"
  depends_on = [rollbar_project.intercode]
  scopes     = ["post_server_item"]
}

# SQS queues used by Shoryuken for background processing
resource "aws_sqs_queue" "intercode_production_dead_letter" {
  name = "intercode_production_dead_letter"
}

resource "aws_sqs_queue" "intercode_production_default" {
  name = "intercode_production_default"
  redrive_policy = jsonencode(
    {
      deadLetterTargetArn = aws_sqs_queue.intercode_production_dead_letter.arn
      maxReceiveCount     = 3
    }
  )
}

resource "aws_sqs_queue" "intercode_production_mailers" {
  name = "intercode_production_mailers"
  redrive_policy = jsonencode(
    {
      deadLetterTargetArn = aws_sqs_queue.intercode_production_dead_letter.arn
      maxReceiveCount     = 3
    }
  )
}

resource "aws_sqs_queue" "intercode_production_ahoy" {
  name = "intercode_production_ahoy"
  redrive_policy = jsonencode(
    {
      deadLetterTargetArn = aws_sqs_queue.intercode_production_dead_letter.arn
      maxReceiveCount     = 3
    }
  )
}

# uploads.neilhosting.net, aka intercode2_production, is the Cloudfront-served S3 bucket we use
# for uploaded CMS content and product images
resource "aws_s3_bucket" "intercode2_production" {
  bucket = "intercode2-production"
}

resource "aws_s3_bucket_acl" "intercode2_production" {
  bucket = aws_s3_bucket.intercode2_production.bucket
  acl    = "private"
}

resource "aws_s3_bucket_cors_configuration" "intercode2_production" {
  bucket = aws_s3_bucket.intercode2_production.bucket

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["*"]
    expose_headers = [
      "Origin",
      "Content-Type",
      "Content-MD5",
      "Content-Disposition"
    ]
    max_age_seconds = 3000
  }
}

resource "cloudflare_record" "uploads_neilhosting_net" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "uploads.neilhosting.net"
  type    = "CNAME"
  value   = module.uploads_neilhosting_net_cloudfront.cloudfront_distribution.domain_name
}

module "uploads_neilhosting_net_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name              = "uploads.neilhosting.net"
  origin_id                = "intercode"
  origin_domain_name       = "www.neilhosting.net"
  origin_protocol_policy   = "https-only"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  cloudflare_zone          = cloudflare_zone.neilhosting_net
  compress                 = true
}

# assets.neilhosting.net is a CloudFront distribution that caches whatever neilhosting.net is
# serving.  Intercode points asset URLs at that domain so that they can be served over CDN
resource "cloudflare_record" "assets_neilhosting_net" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "assets.neilhosting.net"
  type    = "CNAME"
  value   = module.assets_neilhosting_net_cloudfront.cloudfront_distribution.domain_name
}

module "assets_neilhosting_net_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name              = "assets.neilhosting.net"
  origin_id                = "intercode"
  origin_domain_name       = "www.neilhosting.net"
  origin_protocol_policy   = "https-only"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  cloudflare_zone          = cloudflare_zone.neilhosting_net
  compress                 = true
}

resource "aws_cloudwatch_log_group" "intercode2_production" {
  name = "intercode2_production"

  tags = {
    Environment = "production"
    Application = "intercode"
  }

  retention_in_days = 30
}

# IAM policy so that Intercode can access the stuff it needs to access in AWS
resource "aws_iam_group" "intercode2_production" {
  name = "intercode2-production"
}

resource "aws_iam_group_policy" "intercode2_production" {
  name  = "intercode2-production"
  group = aws_iam_group.intercode2_production.name

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
        "${aws_s3_bucket.intercode2_production.arn}/*",
        "${aws_s3_bucket.intercode_inbox.arn}/*"
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
      "Sid": "ShoryukenAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:ChangeMessageVisibility",
        "sqs:ChangeMessageVisibilityBatch",
        "sqs:DeleteMessage",
        "sqs:DeleteMessageBatch",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ReceiveMessage",
        "sqs:SendMessage",
        "sqs:SendMessageBatch",
        "sqs:ListQueues"
      ],
      "Resource": "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:intercode_production_*"
    },
    {
      "Sid": "SesAccess",
      "Effect":"Allow",
      "Action":[
        "ses:SendRawEmail",
        "ses:SendBounce"
      ],
      "Resource":"*"
    },
    {
      "Sid": "SnsAccess",
      "Effect":"Allow",
      "Action":[
        "sns:ConfirmSubscription"
      ],
      "Resource": "${aws_sns_topic.intercode_inbox_deliveries.arn}"
    },
    {
      "Sid": "KmsAccess",
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/2570e363-9e0e-4a1a-b4de-41c2460786df"
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
      "Resource": "${aws_cloudwatch_log_group.intercode2_production.arn}:*"
    },
    {
      "Sid": "CloudwatchSchedulerProvisioning",
      "Effect": "Allow",
      "Action": [
        "sqs:CreateQueue",
        "sqs:GetQueueAttributes",
        "sqs:SetQueueAttributes"
      ],
      "Resource": [
        "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:intercode_production_cloudwatch_scheduler",
        "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:intercode_production_cloudwatch_scheduler-failures"
      ]
    },
    {
      "Sid": "CloudwatchSchedulerAccess",
      "Effect": "Allow",
      "Action": [
        "events:PutRule",
        "events:PutTargets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
  EOF

  # TODO: I can't figure out a good way to avoid hardcoding the key ID in KmsAccess, maybe figure
  # it out later
}

resource "aws_iam_user" "intercode2_production" {
  name = "intercode2-production"
}

resource "aws_iam_user_group_membership" "intercode2_production" {
  user   = aws_iam_user.intercode2_production.name
  groups = [aws_iam_group.intercode2_production.name]
}

resource "aws_iam_access_key" "intercode2_production" {
  user = aws_iam_user.intercode2_production.name
}
