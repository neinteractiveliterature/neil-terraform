locals {
  hosted_org_subdomains = {
    "becon"      = "intercode.fly.dev",
    "gbls"       = "intercode.fly.dev",
    "tapestries" = "intercode.fly.dev"
  }

  neilhosting_net_intercode_subdomains = toset([
    "arisia-2024-beo"
  ])
}

resource "cloudflare_zone" "neilhosting_net" {
  account = {
    id = "9e36b5cabcd5529d3bd08131b7541c06"
  }
  name = "neilhosting.net"
}

resource "cloudflare_zone_setting" "neilhosting_net_ssl" {
  zone_id    = cloudflare_zone.neilhosting_net.id
  setting_id = "ssl"
  value      = "flexible"
}

resource "cloudflare_zone_setting" "neilhosting_net_always_use_https" {
  zone_id    = cloudflare_zone.neilhosting_net.id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "neilhosting_net_security_header" {
  zone_id    = cloudflare_zone.neilhosting_net.id
  setting_id = "security_header"
  value = [{
    enabled            = true
    include_subdomains = true
    preload            = true
    max_age            = 31536000
  }]
}

module "neilhosting_net_apex_redirect" {
  source = "./modules/cloudflare_apex_redirect"

  cloudflare_zone               = cloudflare_zone.neilhosting_net
  domain_name                   = "neilhosting.net"
  redirect_destination_hostname = "www.neilhosting.net"
  redirect_destination_protocol = "https"
  alternative_names             = []
}

module "neilhosting_net_forwardemail_receiving_domain" {
  source = "./modules/forwardemail_receiving_domain"

  cloudflare_zone   = cloudflare_zone.neilhosting_net
  name              = "neilhosting.net"
  verification_code = local.forwardemail_verification_records_by_domain["neilhosting.net"]
}

module "neilhosting_net_intercode_subdomain_forwardemail_receiving_domain" {
  for_each = toset([for subdomain in local.neilhosting_net_intercode_subdomains : "${subdomain}.neilhosting.net"])
  source   = "./modules/forwardemail_receiving_domain"

  cloudflare_zone   = cloudflare_zone.neilhosting_net
  name              = each.value
  verification_code = local.forwardemail_verification_records_by_domain[each.value]
}

resource "cloudflare_dns_record" "neilhosting_net_spf" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "neilhosting.net"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  ttl     = 1
}

resource "cloudflare_dns_record" "neilhosting_net_intercode_subdomain_a" {
  for_each = local.neilhosting_net_intercode_subdomains

  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "${each.value}.neilhosting.net"
  type    = "A"
  content = "137.66.59.126"
  ttl     = 1
}

resource "cloudflare_dns_record" "neilhosting_net_intercode_subdomain_aaaa" {
  for_each = local.neilhosting_net_intercode_subdomains

  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "${each.value}.neilhosting.net"
  type    = "AAAA"
  content = "2a09:8280:1::4e:bee4"
  ttl     = 1
}

resource "cloudflare_dns_record" "neilhosting_net_wildcard_cname" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "*.neilhosting.net"
  type    = "CNAME"
  content = "intercode.fly.dev"
  ttl     = 1
}

resource "cloudflare_dns_record" "neilhosting_net_www_acme_challenge_cname" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "_acme-challenge.www.neilhosting.net"
  type    = "CNAME"
  content = "www.neilhosting.net.j2o5oe.flydns.net"
  ttl     = 1
}

resource "cloudflare_dns_record" "neilhosting_net_hosted_orgs" {
  for_each = local.hosted_org_subdomains
  zone_id  = cloudflare_zone.neilhosting_net.id
  name     = "${each.key}.hosted.neilhosting.net"
  type     = "CNAME"
  content  = trimsuffix(each.value, ".")
  ttl      = 1
}
