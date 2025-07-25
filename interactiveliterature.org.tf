locals {
  intercon_letters = [
    "D", "E", "F", "G", "H", "I", "J", # the Chelmsford years, part I
    "K",                               # that one year in Waltham
    "L", "M", "N", "O",                # the Chelmsford years, part II
    "P",                               # that one year in Westborough
    "Q", "R", "S", "T", "U", "V", "W"  # the Warwick years
  ]
  interactiveliterature_org_intercode_subdomains = toset([
    "irongm",
    "nelco2018",
    "nelco2019",
    "nelco2020",
    "wbc2021",
    "wbc-2023",
    "wbc-2024",
    "wintercon2022",
    "lbc-2023",
    "lbc-2024",
    "lbc-2025"
  ])
  interactiveliterature_org_redirects = {
    "interactiveliterature.org"       = "www.interactiveliterature.org"
    "nelco.interactiveliterature.org" = "nelco2020.interactiveliterature.org"
    "wbc.interactiveliterature.org"   = "wbc-2024.interactiveliterature.org"
  }
}

resource "cloudflare_zone" "interactiveliterature_org" {
  account = {
    id = "9e36b5cabcd5529d3bd08131b7541c06"
  }
  name = "interactiveliterature.org"
}

resource "cloudflare_zone_setting" "interactiveliterature_org_ssl" {
  zone_id    = cloudflare_zone.interactiveliterature_org.id
  setting_id = "ssl"
  value      = "flexible"
}

resource "cloudflare_zone_setting" "interactiveliterature_org_always_use_https" {
  zone_id    = cloudflare_zone.interactiveliterature_org.id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "interactiveliterature_org_security_header" {
  zone_id    = cloudflare_zone.interactiveliterature_org.id
  setting_id = "security_header"
  value = [{
    enabled            = true
    include_subdomains = true
    preload            = true
    max_age            = 31536000
  }]
}

resource "aws_s3_bucket" "interactiveliterature_org_wordpress_backups" {
  bucket = "interactiveliterature.org-wordpress-backups"
}

resource "aws_s3_bucket" "www_interactiveliterature_org" {
  bucket = "www.interactiveliterature.org"
}

resource "aws_s3_bucket_acl" "www_interactiveliterature_org" {
  bucket = aws_s3_bucket.www_interactiveliterature_org.bucket
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "www_interactiveliterature_org" {
  bucket = aws_s3_bucket.www_interactiveliterature_org.bucket
  index_document {
    suffix = "index.html"
  }

  routing_rules = jsonencode(
    concat(
      [
        for letter in local.intercon_letters :
        {
          Condition = {
            HttpErrorCodeReturnedEquals = "404"
            KeyPrefixEquals             = letter
          }
          Redirect = {
            HostName       = "${lower(letter)}.interconlarp.org"
            Protocol       = "https"
            ReplaceKeyWith = ""
          }
        }
      ],
      [
        {
          Condition = {
            HttpErrorCodeReturnedEquals = "404"
            KeyPrefixEquals             = "Wiki"
          }
          Redirect = {
            HostName       = "drive.google.com"
            Protocol       = "https"
            ReplaceKeyWith = "drive/folders/1cw0RHoDGbtoy2i0YtU1aD3U-ww3rOcNN?usp=sharing"
          }
        },
      ]
    )
  )

}

resource "aws_iam_group" "interactiveliterature_org_admin" {
  name = "interactiveliterature.org-admin"
}

resource "aws_iam_group_policy_attachment" "interactiveliterature_org_admin_change_password" {
  group      = aws_iam_group.interactiveliterature_org_admin.name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

resource "aws_iam_group_policy" "interactiveliterature_org_s3" {
  name  = "interactiveliterature.org-s3"
  group = aws_iam_group.interactiveliterature_org_admin.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
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
      "Sid": "bucket",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.www_interactiveliterature_org.bucket}"
      ]
    },
    {
      "Sid": "objects",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.www_interactiveliterature_org.bucket}/*"
      ]
    }
  ]
}
  EOF
}

module "interactiveliterature_org_apex_redirect" {
  for_each = local.interactiveliterature_org_redirects

  source = "./modules/cloudflare_apex_redirect"

  cloudflare_zone               = cloudflare_zone.interactiveliterature_org
  domain_name                   = each.key
  redirect_destination_hostname = each.value
  redirect_destination_protocol = "https"
  alternative_names             = []
}

module "interactiveliterature_org_forwardemail_receiving_domain" {
  source = "./modules/forwardemail_receiving_domain"

  cloudflare_zone   = cloudflare_zone.interactiveliterature_org
  name              = "interactiveliterature.org"
  verification_code = local.forwardemail_verification_records_by_domain["interactiveliterature.org"]
}

resource "cloudflare_dns_record" "interactiveliterature_org_acme_challenge_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "_acme-challenge.interactiveliterature.org"
  type    = "CNAME"
  content = "interactiveliterature.org.j2o5oe.flydns.net"
  ttl     = 1
}

resource "cloudflare_dns_record" "interactiveliterature_org_convention_subdomain_a" {
  for_each = local.interactiveliterature_org_intercode_subdomains

  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "${each.value}.interactiveliterature.org"
  type    = "A"
  content = "137.66.59.126"
  ttl     = 1
}

resource "cloudflare_dns_record" "interactiveliterature_org_convention_subdomain_aaaa" {
  for_each = local.interactiveliterature_org_intercode_subdomains

  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "${each.value}.interactiveliterature.org"
  type    = "AAAA"
  content = "2a09:8280:1::4e:bee4"
  ttl     = 1
}

module "interactiveliterature_org_convention_subdomain_forwardemail_receiving_domain" {
  source = "./modules/forwardemail_receiving_domain"
  for_each = setintersection(
    keys(local.forwardemail_verification_records_by_domain),
    [for subdomain in local.interactiveliterature_org_intercode_subdomains : "${subdomain}.interactiveliterature.org"]
  )

  cloudflare_zone   = cloudflare_zone.interactiveliterature_org
  name              = each.value
  verification_code = local.forwardemail_verification_records_by_domain[each.value]
}

module "interactiveliterature_org_convention_subdomain_events_forwardemail_receiving_domain" {
  source = "./modules/forwardemail_receiving_domain"
  for_each = setintersection(
    keys(local.forwardemail_verification_records_by_domain),
    [for subdomain in local.interactiveliterature_org_intercode_subdomains : "${subdomain}.events.interactiveliterature.org"]
  )

  cloudflare_zone   = each.value
  name              = "events.${each.value}"
  verification_code = local.forwardemail_verification_records_by_domain[each.value]
}

resource "cloudflare_dns_record" "interactiveliterature_org_www_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "www.interactiveliterature.org"
  type    = "CNAME"
  proxied = false
  content = "www-interactiveliterature-org.fly.dev"
  ttl     = 1
}

resource "cloudflare_dns_record" "interactiveliterature_org_old_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "old.interactiveliterature.org"
  type    = "CNAME"
  proxied = false
  content = module.old_interactiveliterature_org_cloudfront.cloudfront_distribution.domain_name
  ttl     = 1
}

module "old_interactiveliterature_org_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name              = "old.interactiveliterature.org"
  origin_id                = "interactiveliterature-org-s3"
  origin_domain_name       = aws_s3_bucket_website_configuration.www_interactiveliterature_org.website_endpoint
  origin_protocol_policy   = "http-only"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  cloudflare_zone          = cloudflare_zone.interactiveliterature_org
  compress                 = true
}

resource "cloudflare_dns_record" "interactiveliterature_org_spf_record" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "interactiveliterature.org"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  ttl     = 1
}

resource "cloudflare_dns_record" "interactiveliterature_org_google_site_verification_record" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "interactiveliterature.org"
  type    = "TXT"
  content = "google-site-verification=iP41tocP1AHGrYev0oaDM8YcwTtCEBYPA9dJddZZ6Yc"
  ttl     = 1
}

resource "cloudflare_dns_record" "interactiveliterature_org_intercode_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "intercode.interactiveliterature.org"
  type    = "CNAME"
  content = "neinteractiveliterature.github.io"
  ttl     = 1
}

resource "cloudflare_dns_record" "interactiveliterature_org_listmonk_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "listmonk.interactiveliterature.org"
  type    = "CNAME"
  content = "neil-listmonk.fly.dev"
  ttl     = 1
}

resource "cloudflare_dns_record" "interactiveliterature_org_litform_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "litform.interactiveliterature.org"
  type    = "CNAME"
  content = "neinteractiveliterature.github.io"
  ttl     = 1
}

resource "cloudflare_dns_record" "interactiveliterature_org_rotator_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "rotator.interactiveliterature.org"
  type    = "CNAME"
  content = "rotator.fly.dev"
  ttl     = 1
}

resource "cloudflare_dns_record" "interactiveliterature_org_wildcard_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "*.interactiveliterature.org"
  type    = "CNAME"
  content = "intercode.fly.dev"
  ttl     = 1
}

resource "cloudflare_dns_record" "interactiveliterature_org_vector" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "vector.interactiveliterature.org"
  type    = "CNAME"
  content = "neil-vector.fly.dev"
  ttl     = 1
}


resource "cloudflare_dns_record" "interactiveliterature_org_vector_acme_challenge" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "_acme-challenge.vector.interactiveliterature.org"
  type    = "CNAME"
  content = "vector.interactiveliterature.org.yzrggx.flydns.net"
  ttl     = 1
}

resource "github_repository" "www_interactiveliterature_org" {
  name                 = "www.interactiveliterature.org"
  description          = "The web site for NEIL"
  has_downloads        = true
  has_issues           = true
  has_projects         = true
  has_wiki             = false
  vulnerability_alerts = true
}

resource "aws_iam_role" "www_interactiveliterature_org_deploy" {
  name = "www_interactiveliterature_org_deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"

      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" : "repo:${github_repository.www_interactiveliterature_org.full_name}:*"
        }
      }

      Principal = {
        Federated = module.github-oidc.oidc_provider_arn
      }
    }]
  })
}

resource "aws_iam_role_policy" "www_interactiveliterature_org_deploy" {
  role = aws_iam_role.www_interactiveliterature_org_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        "Sid" : "ManageBootstrapStateBucket",
        "Effect" : "Allow",
        "Action" : [
          "s3:CreateBucket",
          "s3:PutBucketVersioning",
          "s3:PutBucketNotification",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ],
        "Resource" : [
          "arn:aws:s3:::sst-state-*"
        ]
      },
      {
        "Sid" : "ManageBootstrapAssetBucket",
        "Effect" : "Allow",
        "Action" : [
          "s3:CreateBucket",
          "s3:PutBucketVersioning",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ],
        "Resource" : [
          "arn:aws:s3:::sst-asset-*"
        ]
      },
      {
        "Sid" : "ManageBootstrapECRRepo",
        "Effect" : "Allow",
        "Action" : [
          "ecr:CreateRepository",
          "ecr:DescribeRepositories"
        ],
        "Resource" : [
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/sst-asset"
        ]
      },
      {
        "Sid" : "ManageBootstrapSSMParameter",
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter"
        ],
        "Resource" : [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/sst/passphrase/*",
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/sst/bootstrap"
        ]
      },
      {
        "Sid" : "ManageApplicationProductionBucket",
        "Effect" : "Allow",
        "Action" : [
          "s3:CreateBucket",
          "s3:PutBucketVersioning",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ],
        "Resource" : [
          "arn:aws:s3:::ast-production-*",
          "arn:aws:s3:::sst-asset-*"
        ]
      },
      {
        "Sid" : "ManageLambdaFunctions",
        "Effect" : "Allow",
        "Action" : [
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode",
          "lambda:ListVersionsByFunction",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:InvokeFunction"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Sid" : "ManageCloudfrontDistributions",
        "Effect" : "Allow",
        "Action" : [
          "cloudfront:CreateInvalidation"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

output "www_interactiveliterature_org_github_oidc_role" {
  description = "Game Wrap deploy role ARN"
  value       = aws_iam_role.www_interactiveliterature_org_deploy.arn
}
