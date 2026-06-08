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
    "thepitch.aegames.org",
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

  intercode_production_alarm_email_destinations = toset([
    "natbudin@gmail.com",
    "david@rigitech.com"
  ])
}

# # The Heroku app itself
# resource "heroku_app" "intercode" {
#   name   = "intercode"
#   region = "us"
#   stack  = "container"

#   organization {
#     name = "neinteractiveliterature"
#   }

#   # we do our own cert management shenanigans using scheduled jobs
#   acm = false

#   config_vars = {
#     ASSETS_HOST                         = "assets.neilhosting.net"
#     HEROKU_APP_NAME                     = "intercode"
#     INTERCODE_CERTS_NO_WILDCARD_DOMAINS = "5pi-con.natbudin.com signups.greaterbostonlarpsociety.org thepitch.aegames.org"
#     INTERCODE_HOST                      = "neilhosting.net"
#     JSON_LOGGING                        = "1"
#     MALLOC_ARENA_MAX                    = 2
#     RACK_ENV                            = "production"
#     RAILS_ENV                           = "production"
#     RAILS_GROUPS                        = "skylight"
#     RAILS_LOG_TO_STDOUT                 = "enabled"
#     RAILS_MAX_THREADS                   = "3"
#     RAILS_SERVE_STATIC_FILES            = "enabled"
#     ROLLBAR_CLIENT_ACCESS_TOKEN         = rollbar_project_access_token.intercode_post_client_item.access_token
#     ROLLBAR_PUBLIC_PATH                 = "//neilhosting.net/packs"
#     RUBY_YJIT_ENABLE                    = "1"
#     TWILIO_SMS_NUMBER                   = "+14156345010"
#     UPLOADS_HOST                        = "https://uploads.neilhosting.net"
#     WEB_CONCURRENCY                     = "0"
#   }

#   sensitive_config_vars = {
#     AWS_ACCESS_KEY_ID              = aws_iam_access_key.intercode2_production.id
#     AWS_REGION                     = data.aws_region.current.region
#     AWS_SECRET_ACCESS_KEY          = aws_iam_access_key.intercode2_production.secret
#     AWS_S3_BUCKET                  = aws_s3_bucket.intercode2_production.bucket
#     CF_Account_ID                  = var.intercode_cloudflare_account_id
#     CF_Token                       = var.intercode_cloudflare_token
#     DATABASE_URL                   = "postgres://intercode_production:${var.intercode_production_db_password}@${aws_db_instance.neil_production.endpoint}/intercode_production?sslrootcert=rds-global-bundle.pem"
#     HEROKU_API_TOKEN               = var.intercode_heroku_api_token
#     OPENID_CONNECT_SIGNING_KEY     = var.intercode_openid_connect_signing_key
#     RECAPTCHA_SECRET_KEY           = var.intercode_recaptcha_secret_key
#     RECAPTCHA_SITE_KEY             = var.intercode_recaptcha_site_key
#     ROLLBAR_ACCESS_TOKEN           = rollbar_project_access_token.intercode_post_server_item.access_token
#     SECRET_KEY_BASE                = var.intercode_secret_key_base
#     STRIPE_CONNECT_ENDPOINT_SECRET = var.intercode_stripe_connect_endpoint_secret
#     STRIPE_PUBLISHABLE_KEY         = var.intercode_stripe_publishable_key
#     STRIPE_SECRET_KEY              = var.intercode_stripe_secret_key
#     TWILIO_ACCOUNT_SID             = var.intercode_twilio_account_sid
#     TWILIO_AUTH_TOKEN              = var.intercode_twilio_auth_token
#   }
# }

# resource "heroku_drain" "intercode_vector" {
#   app_id = heroku_app.intercode.id
#   url    = "https://${var.vector_heroku_source_username}:${var.vector_heroku_source_password}@vector.interactiveliterature.org/events?application=intercode"
# }

# resource "heroku_domain" "intercode" {
#   for_each = local.intercode_domains

#   app_id          = heroku_app.intercode.uuid
#   hostname        = each.value
#   sni_endpoint_id = "8b295f16-5ffb-4a02-831c-eac6a080a342"
# }

# resource "heroku_addon" "intercode_memcachedcloud" {
#   app_id = heroku_app.intercode.uuid
#   plan   = "memcachedcloud:30"
# }

# resource "heroku_addon" "intercode_papertrail" {
#   app_id = heroku_app.intercode.uuid
#   plan   = "papertrail:choklad"
# }

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

module "intercode_aws_resources" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/intercode_aws_resources?ref=main&depth=1"

  name                     = "intercode_production"
  s3_bucket_name           = "intercode2-production"
  alarm_email_destinations = local.intercode_production_alarm_email_destinations
}

moved {
  from = aws_sqs_queue.intercode_production_dead_letter
  to   = module.intercode_aws_resources.aws_sqs_queue.dead_letter
}

moved {
  from = aws_sqs_queue.intercode_production_default
  to   = module.intercode_aws_resources.aws_sqs_queue.default
}

moved {
  from = aws_sqs_queue.intercode_production_mailers
  to   = module.intercode_aws_resources.aws_sqs_queue.mailers
}

moved {
  from = aws_sqs_queue.intercode_production_ahoy
  to   = module.intercode_aws_resources.aws_sqs_queue.ahoy
}

moved {
  from = aws_s3_bucket.intercode2_production
  to   = module.intercode_aws_resources.aws_s3_bucket.uploads
}

moved {
  from = aws_s3_bucket_acl.intercode2_production
  to   = module.intercode_aws_resources.aws_s3_bucket_acl.uploads
}

moved {
  from = aws_s3_bucket_cors_configuration.intercode2_production
  to   = module.intercode_aws_resources.aws_s3_bucket_cors_configuration.uploads
}

# aws_sns_topic: name changes "intercode-production-alarms" → "intercode_production-alarms"
# (ForceNew → recreated; alarm email subscribers will need to re-confirm)
moved {
  from = aws_sns_topic.intercode_production_alarms
  to   = module.intercode_aws_resources.aws_sns_topic.alarms
}

# aws_cloudwatch_metric_alarm: alarm_name changes (ForceNew → recreated)
moved {
  from = aws_cloudwatch_metric_alarm.intercode_queue_backup
  to   = module.intercode_aws_resources.aws_cloudwatch_metric_alarm.queue_backup
}

# IAM group/user/access key: names change from "intercode2-production" → "intercode_production"
# (ForceNew → recreated; update app AWS credentials after applying)
moved {
  from = aws_iam_group.intercode2_production
  to   = module.intercode_aws_resources.aws_iam_group.this
}

moved {
  from = aws_iam_user.intercode2_production
  to   = module.intercode_aws_resources.aws_iam_user.this
}

moved {
  from = aws_iam_user_group_membership.intercode2_production
  to   = module.intercode_aws_resources.aws_iam_user_group_membership.this
}

moved {
  from = aws_iam_access_key.intercode2_production
  to   = module.intercode_aws_resources.aws_iam_access_key.this
}

# aws_iam_group_policy.intercode2_production: replaced by two separate module policies
# (intercode_aws_resources base policy + ses_email_receiving inbox policy)

resource "cloudflare_dns_record" "uploads_neilhosting_net" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "uploads.neilhosting.net"
  type    = "CNAME"
  content = module.uploads_neilhosting_net_cloudfront.cloudfront_distribution.domain_name
  ttl     = 1
}

module "uploads_neilhosting_net_cloudfront" {
  source = "github.com/neinteractiveliterature/neil-terraform-modules//cloudfront_with_acm?ref=main"

  domain_name              = "uploads.neilhosting.net"
  origin_id                = "intercode"
  origin_domain_name       = "www.neilhosting.net"
  origin_protocol_policy   = "https-only"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  zone_id = cloudflare_zone.neilhosting_net.id
  compress                 = true
}

resource "cloudflare_dns_record" "assets_neilhosting_net" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "assets.neilhosting.net"
  type    = "CNAME"
  content = module.assets_neilhosting_net_cloudfront.cloudfront_distribution.domain_name
  ttl     = 1
}

module "assets_neilhosting_net_cloudfront" {
  source = "github.com/neinteractiveliterature/neil-terraform-modules//cloudfront_with_acm?ref=main"

  domain_name              = "assets.neilhosting.net"
  origin_id                = "intercode"
  origin_domain_name       = "www.neilhosting.net"
  origin_protocol_policy   = "https-only"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  zone_id = cloudflare_zone.neilhosting_net.id
  compress                 = true
}


resource "github_repository" "intercode" {
  name        = "intercode"
  description = "The future of convention web applications"

  delete_branch_on_merge = true
  has_issues             = true
  has_projects           = true
  has_wiki               = true

  lifecycle {
    ignore_changes = [pages]
  }
}

resource "github_repository_pages" "intercode" {
  repository = github_repository.intercode.name
  build_type = "legacy"
  cname      = cloudflare_dns_record.interactiveliterature_org_intercode_cname.name

  source {
    branch = "gh-pages"
    path   = "/"
  }
}

resource "github_repository_vulnerability_alerts" "intercode" {
  repository = github_repository.intercode.name
}

resource "github_actions_secret" "intercode_fly_api_token" {
  repository      = github_repository.intercode.id
  secret_name     = "FLY_API_TOKEN"
  value = var.fly_gha_api_token
}

resource "sentry_project" "intercode" {
  organization = sentry_organization.neil.slug

  teams    = [sentry_team.neil.slug]
  name     = "intercode"
  slug     = "intercode"
  platform = "ruby-rails"
}

data "sentry_organization_integration" "slack" {
  organization = sentry_organization.neil.slug
  provider_key = "slack"
  name         = "NEIL" # update to match your Slack workspace name in Sentry
}

resource "sentry_metric_monitor" "intercode_response_time" {
  organization = sentry_organization.neil.slug
  project      = sentry_project.intercode.slug
  name         = "p95(span.duration) above 1000ms over past 1 hour"

  aggregate           = "p95(span.duration)"
  dataset             = "events_analytics_platform"
  event_types         = ["trace_item_span"]
  time_window_seconds = 3600

  issue_detection = {
    type = "static"
  }

  condition_group = {
    conditions = [
      {
        type             = "gt"
        comparison       = 1000
        condition_result = 75
      },
      {
        type             = "gt"
        comparison       = 500
        condition_result = 50
      },
      {
        type             = "lte"
        comparison       = 500
        condition_result = 0
      }
    ]
  }
}

resource "sentry_alert" "intercode_response_time" {
  organization      = sentry_organization.neil.slug
  name              = "Intercode response time alert"
  environment       = "production"
  monitor_ids       = [sentry_metric_monitor.intercode_response_time.id]
  frequency_minutes = 30

  trigger_conditions = [
    { first_seen_event = {} }
  ]

  action_filters = [
    {
      logic_type = "all"
      actions = [
        {
          email = {
            fallthrough_type = "ActiveMembers"
            target_type = "issue_owners"
          }
        }
      ]
    }
  ]
}
