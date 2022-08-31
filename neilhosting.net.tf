locals {
  # TODO: delete this once we're off Route 53
  intercode_subdomains = ["www.neilhosting.net", "template.neilhosting.net"]
  hosted_org_subdomains = {
    "becon" = "neilhosting.onrender.com.",
    "gbls"  = "neilhosting.onrender.com."
  }
}

resource "cloudflare_zone" "neilhosting_net" {
  account_id = "9e36b5cabcd5529d3bd08131b7541c06"
  zone       = "neilhosting.net"
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

resource "cloudflare_record" "neilhosting_net_acme_challenge_cname" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "_acme-challenge"
  type    = "CNAME"
  value   = "neilhosting.verify.renderdns.com"
}

resource "cloudflare_record" "neilhosting_net_wildcard_cname" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "*"
  type    = "CNAME"
  value   = "neilhosting.onrender.com"
}

resource "cloudflare_record" "neilhosting_net_cf_custom_hostname_cname" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "_cf-custom-hostname"
  type    = "CNAME"
  value   = "neilhosting.hostname.renderdns.com"
}

resource "cloudflare_record" "neilhosting_net_hosted_orgs" {
  for_each = local.hosted_org_subdomains
  zone_id  = cloudflare_zone.neilhosting_net.id
  name     = "${each.key}.hosted.neilhosting.net"
  type     = "CNAME"
  value    = trimsuffix(each.value, ".")
}
