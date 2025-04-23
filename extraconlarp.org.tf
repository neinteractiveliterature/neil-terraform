locals {
  extraconlarp_org_intercode_subdomains = toset([
    "2021",
    "2022"
  ])
}

resource "cloudflare_zone" "extraconlarp_org" {
  account = {
    id = "9e36b5cabcd5529d3bd08131b7541c06"
  }
  name = "extraconlarp.org"
}

resource "cloudflare_zone_setting" "extraconlarp_org_ssl" {
  zone_id    = cloudflare_zone.extraconlarp_org.id
  id         = "ssl"
  setting_id = "ssl"
  value      = "flexible"
}

resource "cloudflare_zone_setting" "extraconlarp_org_min_tls_version" {
  zone_id    = cloudflare_zone.extraconlarp_org.id
  id         = "min_tls_version"
  setting_id = "min_tls_version"
  value      = "1.2"
}

resource "cloudflare_zone_setting" "extraconlarp_org_always_use_https" {
  zone_id    = cloudflare_zone.extraconlarp_org.id
  id         = "always_use_https"
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "extraconlarp_org_security_header" {
  zone_id    = cloudflare_zone.extraconlarp_org.id
  id         = "security_header"
  setting_id = "security_header"
  value = [{
    enabled            = true
    include_subdomains = true
    preload            = true
    max_age            = 31536000
  }]
}

module "extraconlarp_org_apex_redirect" {
  source = "./modules/cloudflare_apex_redirect"

  cloudflare_zone               = cloudflare_zone.extraconlarp_org
  redirect_destination_hostname = "2021.extraconlarp.org"
  redirect_destination_protocol = "https"
  alternative_names             = ["www.extraconlarp.org"]
}

resource "cloudflare_dns_record" "extraconlarp_org_acme_challenge_cname" {
  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "_acme-challenge.extraconlarp.org"
  type    = "CNAME"
  content = "extraconlarp.org.j2o5oe.flydns.net"
  ttl     = 1
}

resource "cloudflare_dns_record" "extraconlarp_org_convention_subdomain_a" {
  for_each = local.extraconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "${each.value}.extraconlarp.org"
  type    = "A"
  content = "137.66.59.126"
  ttl     = 1
}

resource "cloudflare_dns_record" "extraconlarp_org_convention_subdomain_aaaa" {
  for_each = local.extraconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "${each.value}.extraconlarp.org"
  type    = "AAAA"
  content = "2a09:8280:1::4e:bee4"
  ttl     = 1
}

module "extraconlarp_org_convention_subdomain_forwardemail_receiving_domain" {
  for_each = toset([for subdomain in local.extraconlarp_org_intercode_subdomains : "${subdomain}.extraconlarp.org"])
  source   = "./modules/forwardemail_receiving_domain"

  cloudflare_zone   = cloudflare_zone.extraconlarp_org
  name              = each.value
  verification_code = local.forwardemail_verification_records_by_domain[each.value]
}

module "extraconlarp_org_convention_subdomain_2021_events_forwardemail_receiving_domain" {
  source = "./modules/forwardemail_receiving_domain"

  cloudflare_zone   = cloudflare_zone.extraconlarp_org
  name              = "events.2021.extraconlarp.org"
  verification_code = local.forwardemail_verification_records_by_domain["events.2021.extraconlarp.org"]
}

resource "cloudflare_dns_record" "extraconlarp_org_spf_record" {
  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "extraconlarp.org"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  ttl     = 1
}

resource "cloudflare_dns_record" "extraconlarp_org_google_site_verification_record" {
  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "extraconlarp.org"
  type    = "TXT"
  content = "google-site-verification=FD3Na7QpetcgjXgnJAQUBTwqmyi9oh8LsZ34ODrLuUM"
  ttl     = 1
}

resource "cloudflare_dns_record" "extraconlarp_org_wildcard_cname" {
  zone_id = cloudflare_zone.extraconlarp_org.id
  name    = "*.extraconlarp.org"
  type    = "CNAME"
  content = "intercode.fly.dev"
  ttl     = 1
}
