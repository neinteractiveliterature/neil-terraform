locals {
  hosted_org_subdomains = {
    "becon" = "intercode.fly.dev",
    "gbls"  = "intercode.fly.dev",
  }
}

resource "cloudflare_zone" "neilhosting_net" {
  account_id = "9e36b5cabcd5529d3bd08131b7541c06"
  zone       = "neilhosting.net"
}

resource "cloudflare_zone_settings_override" "neilhosting_net" {
  zone_id = cloudflare_zone.neilhosting_net.id
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

resource "cloudflare_record" "neilhosting_net_a" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "neilhosting.net"
  type    = "A"
  value   = "216.24.57.1"
}

resource "cloudflare_record" "neilhosting_net_mx" {
  zone_id  = cloudflare_zone.neilhosting_net.id
  name     = "neilhosting.net"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "neilhosting_net_spf" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "neilhosting.net"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
}

resource "cloudflare_record" "neilhosting_net_wildcard_cname" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "*"
  type    = "CNAME"
  value   = "intercode.fly.dev"
}

resource "cloudflare_record" "neilhosting_net_www_acme_challenge_cname" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "_acme-challenge.www"
  type    = "CNAME"
  value   = "www.neilhosting.net.j2o5oe.flydns.net."
}

resource "cloudflare_record" "neilhosting_net_hosted_orgs" {
  for_each = local.hosted_org_subdomains
  zone_id  = cloudflare_zone.neilhosting_net.id
  name     = "${each.key}.hosted.neilhosting.net"
  type     = "CNAME"
  value    = trimsuffix(each.value, ".")
}
