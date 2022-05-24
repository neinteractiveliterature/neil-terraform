locals {
  interconlarp_org_intercode_subdomains = toset([
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u"
  ])
  interconlarp_org_redirect_subdomains = toset([
    "a",
    "b",
    "c",
    "xiii",
    "xiv",
    "xv"
  ])
}

resource "cloudflare_zone" "interconlarp_org" {
  zone = "interconlarp.org"
}

resource "aws_s3_bucket" "interconlarp_org" {
  bucket           = "interconlarp.org"
  acl              = "public-read"
  website_domain   = "s3-website-us-east-1.amazonaws.com"
  website_endpoint = "interconlarp.org.s3-website-us-east-1.amazonaws.com"

  versioning {
    enabled    = false
    mfa_delete = false
  }

  website {
    error_document = "error.html"
    index_document = "index.html"
    routing_rules = jsonencode(
      [
        {
          Condition = {
            KeyPrefixEquals = "policy"
          }
          Redirect = {
            HostName         = "u.interconlarp.org"
            HttpRedirectCode = "302"
            Protocol         = "https"
            ReplaceKeyWith   = "pages/rules"
          }
        },
        {
          Redirect = {
            HostName         = "u.interconlarp.org"
            HttpRedirectCode = "302"
            Protocol         = "https"
            ReplaceKeyWith   = ""
          }
        },
      ]
    )
  }
}

module "interconlarp_org_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name       = "interconlarp.org"
  alternative_names = ["www.interconlarp.org"]
  cloudflare_zone   = cloudflare_zone.interconlarp_org
  # TODO disable this once we're on CloudFlare DNS
  validation_method        = "EMAIL"
  origin_id                = "S3-interconlarp.org"
  origin_domain_name       = aws_s3_bucket.interconlarp_org.website_endpoint
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}

# For now, the CloudFlare terraform provider doesn't suport bulk redirects.  This has to be managed via
# the web UI at the moment.  This will hopefully change soon.
#
# https://github.com/cloudflare/terraform-provider-cloudflare/issues/1342
resource "cloudflare_record" "interconlarp_org_nelco_redirect" {
  for_each = local.interconlarp_org_redirect_subdomains

  zone_id = cloudflare_zone.interconlarp_org.id
  name    = each.value
  type    = "A"
  value   = "192.0.2.1"
  proxied = true
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
  value   = "neilhosting.verify.renderdns.com"
}

resource "cloudflare_record" "interconlarp_org_cf_custom_hostname_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "_cf-custom-hostname"
  type    = "CNAME"
  value   = "neilhosting.hostname.renderdns.com"
}

resource "cloudflare_record" "interconlarp_org_convention_subdomain_cname" {
  for_each = local.interconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.interconlarp_org.id
  name    = each.value
  type    = "CNAME"
  value   = "neilhosting.onrender.com"
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

resource "cloudflare_record" "interconlarp_org_amazonses_dkim_record" {
  count = 3

  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "${element(aws_ses_domain_dkim.interconlarp_org.dkim_tokens, count.index)}._domainkey"
  type    = "CNAME"
  value   = "${element(aws_ses_domain_dkim.interconlarp_org.dkim_tokens, count.index)}.dkim.amazonses.com"
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
  value   = "neilhosting.onrender.com"
}

resource "cloudflare_record" "interconlarp_org_furniture_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "furniture"
  type    = "CNAME"
  value   = "intercon-furniture.onrender.com"
}
