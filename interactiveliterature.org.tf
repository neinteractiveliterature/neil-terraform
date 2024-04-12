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
    "wbc-2024",
    "wintercon2022",
    "lbc-2023"
  ])
  interactiveliterature_org_redirects = {
    "interactiveliterature.org"       = "www.interactiveliterature.org"
    "nelco.interactiveliterature.org" = "nelco2020.interactiveliterature.org"
    "wbc.interactiveliterature.org"   = "wbc-2024.interactiveliterature.org"
  }
}

resource "cloudflare_zone" "interactiveliterature_org" {
  account_id = "9e36b5cabcd5529d3bd08131b7541c06"
  zone       = "interactiveliterature.org"
}

resource "cloudflare_zone_settings_override" "interactiveliterature_org" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  settings {
    ssl              = "flexible"
    always_use_https = "on"
    security_header {
      enabled            = true
      include_subdomains = true
      preload            = true
      max_age            = 31536000
    }
  }
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
  value   = "interactiveliterature.org.j2o5oe.flydns.net."
}

resource "cloudflare_record" "interactiveliterature_org_convention_subdomain_a" {
  for_each = local.interactiveliterature_org_intercode_subdomains

  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = each.value
  type    = "A"
  value   = "66.241.124.95"
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
  proxied = true
  value   = aws_s3_bucket_website_configuration.www_interactiveliterature_org.website_endpoint
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
  value   = "neil-listmonk.fly.dev"
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
  value   = "intercode.fly.dev"
}

resource "cloudflare_record" "interactiveliterature_org_vector" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "vector"
  type    = "CNAME"
  value   = "neil-vector.fly.dev"
}


resource "cloudflare_record" "interactiveliterature_org_vector_acme_challenge" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "_acme-challenge.vector"
  type    = "CNAME"
  value   = "vector.interactiveliterature.org.yzrggx.flydns.net"
}
