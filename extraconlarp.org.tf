locals {
  cloudflare_zone_id = "da83fa981604d240175058922e531964"
  convention_subdomains = toset([
    "2021"
  ])
}

module "extraconlarp_org_cloudfront" {
  source = "./modules/cloudfront_apex_redirect"

  cloudflare_zone = {
    zone_id : local.cloudflare_zone_id,
    name : "extraconlarp.org"
  }
  redirect_destination     = "https://2021.extraconlarp.org"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  alternative_names        = ["www.extraconlarp.org"]
}

resource "cloudflare_record" "extraconlarp_org_mx" {
  zone_id  = local.cloudflare_zone_id
  name     = "extraconlarp.org"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "extraconlarp_org_wildcard_cname" {
  zone_id = local.cloudflare_zone_id
  name    = "*"
  type    = "CNAME"
  value   = "neilhosting.onrender.com"
}

resource "cloudflare_record" "extraconlarp_org_acme_challenge_cname" {
  zone_id = local.cloudflare_zone_id
  name    = "_acme-challenge"
  type    = "CNAME"
  value   = "neilhosting.verify.renderdns.com"
}

resource "cloudflare_record" "extraconlarp_org_cf_custom_hostname_cname" {
  zone_id = local.cloudflare_zone_id
  name    = "_cf-custom-hostname"
  type    = "CNAME"
  value   = "neilhosting.hostname.renderdns.com"
}

resource "cloudflare_record" "extraconlarp_org_convention_subdomain_cname" {
  for_each = local.convention_subdomains

  zone_id = local.cloudflare_zone_id
  name    = each.value
  type    = "CNAME"
  value   = "neilhosting.onrender.com"
}

resource "cloudflare_record" "extraconlarp_org_convention_subdomain_mx" {
  for_each = local.convention_subdomains

  zone_id  = local.cloudflare_zone_id
  name     = each.value
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "extraconlarp_org_convention_subdomain_events_mx" {
  for_each = local.convention_subdomains

  zone_id  = local.cloudflare_zone_id
  name     = "events.${each.value}"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "extraconlarp_org_amazonses_dkim_record" {
  count = 3

  zone_id = local.cloudflare_zone_id
  name    = "${element(aws_ses_domain_dkim.extraconlarp_org.dkim_tokens, count.index)}._domainkey"
  type    = "CNAME"
  value   = "${element(aws_ses_domain_dkim.extraconlarp_org.dkim_tokens, count.index)}.dkim.amazonses.com"
}

resource "cloudflare_record" "extraconlarp_org_spf_record" {
  zone_id = local.cloudflare_zone_id
  name    = "extraconlarp.org"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
}

resource "cloudflare_record" "extraconlarp_org_google_site_verification_record" {
  zone_id = local.cloudflare_zone_id
  name    = "extraconlarp.org"
  type    = "TXT"
  value   = "google-site-verification=FD3Na7QpetcgjXgnJAQUBTwqmyi9oh8LsZ34ODrLuUM"
}
