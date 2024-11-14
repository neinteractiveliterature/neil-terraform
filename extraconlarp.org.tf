locals {
  extraconlarp_org_intercode_subdomains = toset([
    "2021"
  ])
}

resource "cloudflare_zone" "extraconlarp_org" {
  account_id = "9e36b5cabcd5529d3bd08131b7541c06"
  zone       = "extraconlarp.org"
}

resource "cloudflare_zone_settings_override" "extraconlarp_org" {
  zone_id = cloudflare_zone.extraconlarp_org.id
  settings {
    ssl              = "flexible"
    always_use_https = "on"
    min_tls_version  = "1.2"
    security_header {
      enabled            = true
      include_subdomains = true
      preload            = true
      max_age            = 31536000
    }
  }
}

module "extraconlarp_org_apex_redirect" {
  source = "./modules/cloudflare_apex_redirect"

  cloudflare_zone               = cloudflare_zone.extraconlarp_org
  redirect_destination_hostname = "2021.extraconlarp.org"
  redirect_destination_protocol = "https"
  alternative_names             = ["www.extraconlarp.org"]
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
  value   = "extraconlarp.org.j2o5oe.flydns.net"
}

resource "cloudflare_record" "extraconlarp_org_convention_subdomain_a" {
  for_each = local.extraconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = each.value
  type    = "A"
  value   = "137.66.59.126"
}

resource "cloudflare_record" "extraconlarp_org_convention_subdomain_aaaa" {
  for_each = local.extraconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = each.value
  type    = "AAAA"
  value   = "2a09:8280:1::4e:bee4"
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
  value   = "intercode.fly.dev"
}
