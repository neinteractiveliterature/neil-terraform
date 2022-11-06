locals {
  # TODO: delete this once we're off Route 53
  intercode_subdomains = ["www.neilhosting.net", "template.neilhosting.net"]
  hosted_org_subdomains = {
    "becon" = heroku_domain.intercode["2019.beconlarp.com"].cname,
    "gbls"  = heroku_domain.intercode["signups.greaterbostonlarpsociety.org"].cname
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

resource "cloudflare_record" "neilhosting_net_wildcard_cname" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "*"
  type    = "CNAME"
  value   = heroku_domain.intercode["*.neilhosting.net"].cname
}

resource "cloudflare_record" "neilhosting_net_hosted_orgs" {
  for_each = local.hosted_org_subdomains
  zone_id  = cloudflare_zone.neilhosting_net.id
  name     = "${each.key}.hosted.neilhosting.net"
  type     = "CNAME"
  value    = trimsuffix(each.value, ".")
}
