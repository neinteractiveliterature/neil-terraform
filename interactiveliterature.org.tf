locals {
  intercon_letters = [
    "D", "E", "F", "G", "H", "I", "J", # the Chelmsford years, part I
    "K",                               # that one year in Waltham
    "L", "M", "N", "O",                # the Chelmsford years, part II
    "P",                               # that one year in Westborough
    "Q", "R", "S", "T", "U", "V"       # the Warwick years
  ]
  interactiveliterature_org_intercode_subdomains = toset([
    "irongm",
    "nelco2018",
    "nelco2019",
    "nelco2020",
    "wbc2021",
    "wintercon2022",
    "lbc-2023"
  ])
}

resource "cloudflare_zone" "interactiveliterature_org" {
  account_id = "9e36b5cabcd5529d3bd08131b7541c06"
  zone       = "interactiveliterature.org"
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

resource "aws_iam_group_policy" "interactiveliterature_org_cloudfront" {
  name  = "interactiveliterature.org-cloudfront"
  group = aws_iam_group.interactiveliterature_org_admin.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DistributionLevelAccess",
      "Effect": "Allow",
      "Action": [
        "cloudfront:ListDistributions",
        "cloudfront:ListStreamingDistributions"
      ],
      "Resource": ["*"]
    },
    {
      "Sid": "Stmt1545167594000",
      "Effect": "Allow",
      "Action": [
        "cloudfront:*"
      ],
      "Resource": [
        "${module.interactiveliterature_org_cloudfront.cloudfront_distribution.arn}"
      ]
    }
  ]
}
  EOF
}

module "interactiveliterature_org_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name              = "interactiveliterature.org"
  cloudflare_zone          = cloudflare_zone.interactiveliterature_org
  alternative_names        = ["www.interactiveliterature.org"]
  origin_id                = "S3-Website-www.interactiveliterature.org.s3-website-us-east-1.amazonaws.com"
  origin_domain_name       = aws_s3_bucket_website_configuration.www_interactiveliterature_org.website_endpoint
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}

module "interactiveliterature_org_nelco_redirect" {
  source = "./modules/cloudfront_apex_redirect"

  cloudflare_zone               = cloudflare_zone.interactiveliterature_org
  domain_name                   = "nelco.interactiveliterature.org"
  redirect_destination_hostname = "nelco2020.interactiveliterature.org"
  redirect_destination_protocol = "https"
  add_security_headers_arn      = aws_lambda_function.addSecurityHeaders.qualified_arn
  alternative_names             = []
}

resource "cloudflare_record" "interactiveliterature_org_apex_alias" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "interactiveliterature.org"
  type    = "CNAME"
  value   = module.interactiveliterature_org_cloudfront.cloudfront_distribution.domain_name
}

resource "cloudflare_record" "interactiveliterature_org_mx" {
  zone_id  = cloudflare_zone.interactiveliterature_org.id
  name     = "interactiveliterature.org"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "interactiveliterature_org_acme_challenge_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "_acme-challenge"
  type    = "CNAME"
  value   = "_acme-challenge.neilhosting.net."
}

resource "cloudflare_record" "interactiveliterature_org_convention_subdomain_cname" {
  for_each = local.interactiveliterature_org_intercode_subdomains

  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = each.value
  type    = "CNAME"
  value   = heroku_domain.intercode["*.interactiveliterature.org"].cname
  proxied = true
}

resource "cloudflare_record" "interactiveliterature_org_convention_subdomain_mx" {
  for_each = local.interactiveliterature_org_intercode_subdomains

  zone_id  = cloudflare_zone.interactiveliterature_org.id
  name     = each.value
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "interactiveliterature_org_convention_subdomain_events_mx" {
  for_each = local.interactiveliterature_org_intercode_subdomains

  zone_id  = cloudflare_zone.interactiveliterature_org.id
  name     = "events.${each.value}"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "interactiveliterature_org_www_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "www"
  type    = "CNAME"
  value   = module.interactiveliterature_org_cloudfront.cloudfront_distribution.domain_name
}

resource "cloudflare_record" "interactiveliterature_org_spf_record" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "interactiveliterature.org"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
}

resource "cloudflare_record" "interactiveliterature_org_google_site_verification_record" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "interactiveliterature.org"
  type    = "TXT"
  value   = "google-site-verification=iP41tocP1AHGrYev0oaDM8YcwTtCEBYPA9dJddZZ6Yc"
}

resource "cloudflare_record" "interactiveliterature_org_intercode_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "intercode"
  type    = "CNAME"
  value   = "neinteractiveliterature.github.io"
}

resource "cloudflare_record" "interactiveliterature_org_listmonk_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "listmonk"
  type    = "CNAME"
  value   = heroku_domain.listmonk_interactiveliterature_org.cname
}

resource "cloudflare_record" "interactiveliterature_org_litform_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "litform"
  type    = "CNAME"
  value   = "neinteractiveliterature.github.io"
}

resource "cloudflare_record" "interactiveliterature_org_wildcard_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "*"
  type    = "CNAME"
  value   = heroku_domain.intercode["*.interactiveliterature.org"].cname
}


