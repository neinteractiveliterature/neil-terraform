locals {
  larp_library_domains = toset([
    "library.interactiveliterature.org",
    "www.larplibrary.org"
  ])

  larp_library_cors_allowed_origins = [for domain in local.larp_library_domains : "https://${domain}"]
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
  account = {
    id = "9e36b5cabcd5529d3bd08131b7541c06"
  }
  name = "larplibrary.org"
}

module "larplibrary_org_apex_redirect" {
  source = "github.com/neinteractiveliterature/neil-terraform-modules//cloudflare_apex_redirect?ref=main"

  zone_id                       = cloudflare_zone.larplibrary_org.id
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

module "larplibrary_org_forwardemail_receiving_domain" {
  source = "github.com/neinteractiveliterature/neil-terraform-modules//forwardemail_receiving_domain?ref=main"

  zone_id           = cloudflare_zone.larplibrary_org.id
  name              = "larplibrary.org"
  verification_code = module.forwardemail_receiving.verification_records_by_domain["larplibrary.org"]
}

resource "cloudflare_dns_record" "assets_larplibrary_org" {
  zone_id = cloudflare_zone.larplibrary_org.id
  name    = "assets.larplibrary.org"
  type    = "CNAME"
  content = module.assets_larplibrary_org_cloudfront.cloudfront_distribution.domain_name
  ttl     = 1
}


module "assets_larplibrary_org_cloudfront" {
  source = "github.com/neinteractiveliterature/neil-terraform-modules//cloudfront_with_acm?ref=main"

  domain_name              = "assets.larplibrary.org"
  origin_id                = "larplibrary"
  origin_domain_name       = "www.larplibrary.org"
  origin_protocol_policy   = "https-only"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  zone_id                  = cloudflare_zone.larplibrary_org.id
  compress                 = true
}

resource "github_repository" "larp_library" {
  name        = "larp_library"
  description = "A site for hosting free-to-run larps"

  delete_branch_on_merge = true
  has_issues             = true
  has_projects           = true
  has_wiki               = true
}

resource "github_repository_vulnerability_alerts" "larp_library" {
  repository = github_repository.larp_library.name
}

resource "github_actions_secret" "larp_library_fly_api_token" {
  repository  = github_repository.larp_library.id
  secret_name = "FLY_API_TOKEN"
  value       = local.secrets["larp_library_fly_api_token"]
}

# Deploys the app with SST (see the larp_library repo's sst.config.ts and release workflow), the way rotator and gamewrap
# are deployed. This creates the deploy role the release workflow assumes and the AWS_OIDC_ROLE / CLOUDFLARE_* secrets it
# reads. "library.interactiveliterature.org" redirects to the app, so SST needs to write that zone as well as larplibrary.org.
module "larp_library_sst_github_deployment" {
  source = "github.com/neinteractiveliterature/neil-terraform-modules//sst_github_deployment?ref=main"

  app_name              = "larp-library"
  cloudflare_account_id = cloudflare_account.neil.id
  github_repository = {
    name      = github_repository.larp_library.name
    full_name = github_repository.larp_library.full_name
  }
  oidc_provider_arn = module.github-oidc.oidc_provider_arn
  writable_cloudflare_zones = [
    cloudflare_zone.larplibrary_org.id,
    cloudflare_zone.interactiveliterature_org.id,
  ]
}

resource "sentry_project" "larp_library" {
  organization = sentry_organization.neil.slug

  teams    = [sentry_team.neil.slug]
  name     = "Larp Library"
  slug     = "larp-library"
  platform = "ruby-rails"
}

resource "github_actions_secret" "larp_library_sentry_org" {
  repository  = github_repository.larp_library.name
  secret_name = "SENTRY_ORG"
  value       = sentry_organization.neil.slug
}

resource "github_actions_secret" "larp_library_sentry_project" {
  repository  = github_repository.larp_library.name
  secret_name = "SENTRY_PROJECT"
  value       = sentry_project.larp_library.slug
}

resource "github_actions_secret" "larp_library_sentry_auth_token" {
  repository  = github_repository.larp_library.name
  secret_name = "SENTRY_AUTH_TOKEN"
  value       = var.sentry_auth_token
}

data "sentry_all_keys" "larp_library" {
  organization = sentry_organization.neil.slug
  project      = sentry_project.larp_library.slug
}

# larp_library has no chamber/SSM setup (unlike intercode) — it reads plain
# Fly env vars. SENTRY_DSN/SENTRY_ORGANIZATION_ID/SENTRY_PROJECT_SLUGS are
# not secret and belong in fly.toml [env]. SENTRY_RELEASE_TOKEN is secret and
# is not managed here (no fly provider — see fly_oidc.tf for why automating
# flyctl secrets is avoided); set it by hand after apply:
#   flyctl secrets set --app larp-library \
#     SENTRY_RELEASE_TOKEN=$(tofu output -raw larp_library_sentry_release_token)


# The deploy role's own S3 statement is scoped to "larp-library-production-*", which doesn't match this bucket (it has no
# suffix). SST imports the bucket rather than creating it, so the role needs to read its configuration. Read-only: the
# bucket itself stays managed here.
resource "aws_iam_role_policy" "larp_library_deploy_read_uploads_bucket" {
  name = "read-uploads-bucket"
  role = reverse(split("/", module.larp_library_sst_github_deployment.aws_deploy_oidc_role))[0]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadUploadsBucketConfiguration"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:ListTagsForResource",
          "s3:GetBucketTagging",
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketWebsite",
          "s3:GetBucketVersioning",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketLogging",
          "s3:GetLifecycleConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketPublicAccessBlock",
        ]
        Resource = aws_s3_bucket.larp_library_production.arn
      }
    ]
  })
}

# The sst_github_deployment module's policy has no IAM role actions and a log-group statement that doesn't match how the
# AWS provider reads log groups, so it can't deploy a stack that creates its own Lambda functions (the web function and
# the migrator). This fills the gap for this app only. Everything SST creates is named "larp-lib*-production-*" (it
# shortens "larp-library" to "larp-lib" in S3 bucket names).
#
# The actions are the ones CloudTrail showed the role using in the first successful deploy, plus the update and delete
# counterparts of the ones it creates, which later deploys and teardowns need. CloudFront, ACM and SSM access comes from
# the module's own policy.
resource "aws_iam_role_policy" "larp_library_deploy_sst_resources" {
  name = "sst-resources"
  role = reverse(split("/", module.larp_library_sst_github_deployment.aws_deploy_oidc_role))[0]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageApplicationRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:PassRole",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/larp-lib*-production-*"
      },
      {
        # SST attaches only the basic Lambda logging policy to its function roles
        Sid      = "AttachLambdaLoggingPolicy"
        Effect   = "Allow"
        Action   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/larp-lib*-production-*"
        Condition = {
          ArnEquals = {
            "iam:PolicyARN" = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
          }
        }
      },
      {
        Sid    = "ManageApplicationLogGroups"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagResource",
          "logs:UntagResource",
          "logs:ListTagsForResource",
          "logs:ListTagsLogGroup",
        ]
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/larp-lib*-production-*"
      },
      {
        # The provider reads a log group by listing them, which is only authorized against this resource
        Sid      = "FindLogGroups"
        Effect   = "Allow"
        Action   = "logs:DescribeLogGroups"
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group::log-stream:"
      },
      {
        Sid    = "ManageApplicationFunctions"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:ListVersionsByFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PutFunctionConcurrency",
          "lambda:DeleteFunctionConcurrency",
          "lambda:InvokeFunction",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:CreateFunctionUrlConfig",
          "lambda:GetFunctionUrlConfig",
          "lambda:UpdateFunctionUrlConfig",
          "lambda:DeleteFunctionUrlConfig",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
        ]
        Resource = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:larp-lib*-production-*"
      },
      {
        Sid    = "ManageApplicationBuckets"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:PutBucketCORS",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketWebsite",
          "s3:DeleteBucketWebsite",
          "s3:PutBucketTagging",
          "s3:GetBucket*",
          "s3:GetAccelerateConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:ListBucket",
          "s3:ListTagsForResource",
        ]
        Resource = "arn:aws:s3:::larp-lib*-production-*"
      },
      {
        Sid    = "ManageApplicationBucketObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectTagging",
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:DeleteObject",
        ]
        Resource = "arn:aws:s3:::larp-lib*-production-*/*"
      },
    ]
  })
}
