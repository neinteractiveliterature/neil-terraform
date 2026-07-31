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
    "natbudin@gmail.com"
  ])
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

resource "random_password" "intercode_production_db" {
  length  = 32
  special = false
}

import {
  to = postgresql_role.intercode_production
  id = "intercode_production"
}

resource "postgresql_role" "intercode_production" {
  name     = "intercode_production"
  login    = true
  password = random_password.intercode_production_db.result

  # This role predates Terraform management; only take over login/password
  # here and leave every other already-set attribute (connection_limit,
  # roles, superuser, etc.) exactly as it is so import can't reset something
  # unexpected on the live production role.
  lifecycle {
    ignore_changes = [
      superuser,
      create_database,
      create_role,
      replication,
      bypass_row_level_security,
      inherit,
      connection_limit,
      search_path,
      valid_until,
      statement_timeout,
      roles,
      skip_reassign_owned,
      skip_drop_role,
    ]
  }
}

# Grants rds_iam to intercode_production, which makes AWS require an IAM
# auth token for this role and immediately rejects its password (confirmed
# via AWS docs — not gradual/coexisting, same as it was for neiladmin). Only
# safe now that the app (pg-aws_rds_iam, deployed) generates its own tokens
# instead of using a stored password for DATABASE_URL.
resource "postgresql_grant_role" "intercode_production_rds_iam" {
  role       = postgresql_role.intercode_production.name
  grant_role = "rds_iam"
}

# Wraps the connection string in terraform_data so we can force it to wait
# on the rds_iam grant above via depends_on — database_url itself doesn't
# reference the grant's attributes, so without this, nothing would stop the
# new token-based URL from reaching SSM before the grant that makes tokens
# actually valid has landed.
resource "terraform_data" "intercode_production_database_url" {
  input = "postgres://${postgresql_role.intercode_production.name}@${aws_db_instance.neil_production.endpoint}/intercode_production?sslrootcert=rds-global-bundle.pem&aws_rds_iam_auth_token_generator=default"

  depends_on = [postgresql_grant_role.intercode_production_rds_iam]
}

# Replaces the old Connect webhook endpoint (whose secret was a plain
# tfvar) with one Terraform can generate and rotate itself: creating a new
# stripe_webhook_endpoint gets a fresh secret directly from Stripe, and the
# old endpoint (whatever's currently configured for this URL/events in the
# Stripe dashboard) can be deleted by hand once this one's confirmed working
# — Stripe's API has no in-place secret rotation, only new-endpoint-new-secret.
resource "stripe_webhook_endpoint" "intercode_connect" {
  url = "https://www.neilhosting.net/stripe_webhook/connect"
  enabled_events = [
    "account.application.authorized",
    "account.application.deauthorized",
    "account.updated",
  ]
  connect     = true
  description = "intercode_production Connect webhook (Terraform-managed)"
}

module "intercode_aws_resources" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/intercode_aws_resources?ref=main&depth=1"

  name                       = "intercode_production"
  s3_bucket_name             = "intercode2-production"
  alarm_email_destinations   = local.intercode_production_alarm_email_destinations
  database_url                  = terraform_data.intercode_production_database_url.output
  fly_api_token                 = local.secrets["intercode_fly_api_token"]
  default_currency              = "USD"

  stripe = {
    secret_key              = local.secrets["intercode_stripe_secret_key"]
    publishable_key         = local.secrets["intercode_stripe_publishable_key"]
    connect_endpoint_secret = stripe_webhook_endpoint.intercode_connect.secret
  }

  recaptcha = {
    secret_key = local.secrets["intercode_recaptcha_secret_key"]
    site_key   = local.secrets["intercode_recaptcha_site_key"]
  }

  twilio = {
    account_sid = local.secrets["intercode_twilio_account_sid"]
    auth_token  = local.secrets["intercode_twilio_auth_token"]
    sms_number  = "+14156345010"
  }

  assets_host                         = "assets.neilhosting.net"
  uploads_host                        = "https://uploads.neilhosting.net"
  cloudwatch_log_group                = "intercode2_production"
  intercode_host                      = "www.neilhosting.net"

  autoscale = {
    min_instances = 2
    max_instances = 10
  }
}

# Lets the app's existing AWS identity (the IAM user/group above) generate
# RDS IAM auth tokens for intercode_production once pg-aws_rds_iam is wired
# up app-side. Purely additive/permissions-granting on its own — safe ahead
# of actually switching database_url over, unlike the rds_iam grant itself.
resource "aws_iam_group_policy" "intercode_production_rds_iam_auth" {
  name  = "rds-iam-auth"
  group = module.intercode_aws_resources.iam_group_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RdsIamAuthConnect"
        Effect   = "Allow"
        Action   = "rds-db:connect"
        Resource = "arn:aws:rds-db:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.neil_production.resource_id}/intercode_production"
      }
    ]
  })
}

module "intercode_sentry" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/sentry?ref=main&depth=1"

  ssm_name             = "intercode_production"
  organization         = sentry_organization.neil.slug
  project              = sentry_project.intercode.slug
  release_token        = local.secrets["intercode_sentry_release_token"]
  traces_sample_rate   = "1.0"
  profiles_sample_rate = "1.0"
}

resource "null_resource" "intercode_fly_redeploy" {
  triggers = {
    aws_resources_version = module.intercode_aws_resources.ssm_parameters_version
    sentry_version        = module.intercode_sentry.ssm_parameters_version
    forwardemail_version  = module.forwardemail_receiving.ssm_parameters_version
  }

  provisioner "local-exec" {
    command = "flyctl deploy --app intercode --remote-only"
  }
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
  value = local.secrets["fly_gha_api_token"]
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

