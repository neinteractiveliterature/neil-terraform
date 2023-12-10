locals {
  interconlarp_org_intercode_subdomains = toset([
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v"
  ])
  interconlarp_org_redirect_subdomains = {
    "a.interconlarp.org"    = "www.interactiveliterature.org/A",
    "b.interconlarp.org"    = "www.interactiveliterature.org/B",
    "c.interconlarp.org"    = "www.interactiveliterature.org/C",
    "xiii.interconlarp.org" = "www.interactiveliterature.org/XIII",
    "xiv.interconlarp.org"  = "www.interactiveliterature.org/XIV",
    "xv.interconlarp.org"   = "www.interactiveliterature.org/XV"
  }
}

resource "cloudflare_zone" "interconlarp_org" {
  account_id = "9e36b5cabcd5529d3bd08131b7541c06"
  zone       = "interconlarp.org"
}

resource "aws_s3_bucket" "interconlarp_org" {
  bucket = "interconlarp.org"
}

resource "aws_s3_bucket_acl" "interconlarp_org" {
  bucket = aws_s3_bucket.interconlarp_org.bucket
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "interconlarp_org" {
  bucket = aws_s3_bucket.interconlarp_org.bucket
  error_document {
    key = "error.html"
  }
  index_document {
    suffix = "index.html"
  }
  routing_rules = jsonencode(
    [
      {
        Condition = {
          KeyPrefixEquals = "policy"
        }
        Redirect = {
          HostName         = "v.interconlarp.org"
          HttpRedirectCode = "302"
          Protocol         = "https"
          ReplaceKeyWith   = "pages/rules"
        }
      },
      {
        Redirect = {
          HostName         = "v.interconlarp.org"
          HttpRedirectCode = "302"
          Protocol         = "https"
          ReplaceKeyWith   = ""
        }
      },
    ]
  )
}

module "interconlarp_org_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name              = "interconlarp.org"
  alternative_names        = ["www.interconlarp.org"]
  cloudflare_zone          = cloudflare_zone.interconlarp_org
  origin_id                = "S3-interconlarp.org"
  origin_domain_name       = aws_s3_bucket_website_configuration.interconlarp_org.website_endpoint
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}

module "interconlarp_org_redirect_subdomain" {
  for_each = local.interconlarp_org_redirect_subdomains

  source = "./modules/cloudfront_apex_redirect"

  cloudflare_zone               = cloudflare_zone.interconlarp_org
  domain_name                   = each.key
  redirect_destination_hostname = each.value
  redirect_destination_protocol = "https"
  add_security_headers_arn      = aws_lambda_function.addSecurityHeaders.qualified_arn
  alternative_names             = []
}

resource "cloudflare_record" "interconlarp_org_apex_alias" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "interconlarp.org"
  type    = "CNAME"
  value   = module.interconlarp_org_cloudfront.cloudfront_distribution.domain_name
}

resource "cloudflare_record" "interconlarp_org_mx" {
  zone_id  = cloudflare_zone.interconlarp_org.id
  name     = "interconlarp.org"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "interconlarp_org_acme_challenge_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "_acme-challenge"
  type    = "CNAME"
  value   = "_acme-challenge.neilhosting.net."
}

resource "cloudflare_record" "interconlarp_org_convention_subdomain_cname" {
  for_each = local.interconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.interconlarp_org.id
  name    = each.value
  type    = "CNAME"
  value   = heroku_domain.intercode["*.interconlarp.org"].cname
  proxied = true
}

resource "cloudflare_record" "interconlarp_org_convention_subdomain_mx" {
  for_each = local.interconlarp_org_intercode_subdomains

  zone_id  = cloudflare_zone.interconlarp_org.id
  name     = each.value
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "interconlarp_org_convention_subdomain_events_mx" {
  for_each = local.interconlarp_org_intercode_subdomains

  zone_id  = cloudflare_zone.interconlarp_org.id
  name     = "events.${each.value}"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "interconlarp_org_www_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "www"
  type    = "CNAME"
  value   = module.interconlarp_org_cloudfront.cloudfront_distribution.domain_name
}

resource "cloudflare_record" "interconlarp_org_spf_record" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "interconlarp.org"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
}

resource "cloudflare_record" "interconlarp_org_google_site_verification_record" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "interconlarp.org"
  type    = "TXT"
  value   = "google-site-verification=RzGiDCnUV6z9mlwsITO48YkMEx6g3V44fGoD7qMYMDE"
}

resource "cloudflare_record" "interconlarp_org_wildcard_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "*"
  type    = "CNAME"
  value   = heroku_domain.intercode["*.interconlarp.org"].cname
}

resource "cloudflare_record" "interconlarp_org_furniture_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "furniture"
  type    = "CNAME"
  value   = heroku_domain.intercon_furniture["furniture.interconlarp.org"].cname
}

resource "cloudflare_record" "interconlarp_org_i_fly_temp" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "i"
  type    = "CNAME"
  value   = "intercode.fly.dev"
}

resource "cloudflare_record" "interconlarp_org_i_acme_challenge_fly_temp" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "_acme-challenge.i"
  type    = "CNAME"
  value   = "i.interconlarp.org.j2o5oe.flydns.net"
}
