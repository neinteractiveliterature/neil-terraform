locals {
  extraconlarp_org_intercode_subdomains = toset([
    "2021"
  ])
}

resource "cloudflare_zone" "extraconlarp_org" {
  zone = "extraconlarp.org"
}

module "extraconlarp_org_cloudfront" {
  source = "./modules/cloudfront_apex_redirect"

  cloudflare_zone          = cloudflare_zone.extraconlarp_org
  redirect_destination     = "https://2021.extraconlarp.org"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  alternative_names        = ["www.extraconlarp.org"]
}

resource "cloudflare_record" "extraconlarp_org_mx" {
  zone_id  = cloudflare_zone.extraconlarp_org.id
  name     = "extraconlarp.org"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "extraconlarp_org_acme_challenge_cname" {
  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "_acme-challenge"
  type    = "CNAME"
  value   = "neilhosting.verify.renderdns.com"
}

resource "cloudflare_record" "extraconlarp_org_cf_custom_hostname_cname" {
  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "_cf-custom-hostname"
  type    = "CNAME"
  value   = "neilhosting.hostname.renderdns.com"
}

resource "cloudflare_record" "extraconlarp_org_convention_subdomain_cname" {
  for_each = local.extraconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = each.value
  type    = "CNAME"
  value   = "neilhosting.onrender.com"
  proxied = true
}

resource "cloudflare_record" "extraconlarp_org_convention_subdomain_mx" {
  for_each = local.extraconlarp_org_intercode_subdomains

  zone_id  = cloudflare_zone.extraconlarp_org.id
  name     = each.value
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "extraconlarp_org_convention_subdomain_events_mx" {
  for_each = local.extraconlarp_org_intercode_subdomains

  zone_id  = cloudflare_zone.extraconlarp_org.id
  name     = "events.${each.value}"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "extraconlarp_org_spf_record" {
  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "extraconlarp.org"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
}

resource "cloudflare_record" "extraconlarp_org_google_site_verification_record" {
  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "extraconlarp.org"
  type    = "TXT"
  value   = "google-site-verification=FD3Na7QpetcgjXgnJAQUBTwqmyi9oh8LsZ34ODrLuUM"
}

resource "cloudflare_record" "extraconlarp_org_wildcard_cname" {
  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "*"
  type    = "CNAME"
  value   = "neilhosting.onrender.com"
}
