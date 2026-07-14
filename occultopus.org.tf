locals {
  occultopus_org_cnames = {
    "*"                    = "j2o5oe.intercode.fly.dev"
    "_acme-challenge"      = "occultopus.org.j2o5oe.flydns.net"
  }
}

resource "cloudflare_zone" "occultopus_org" {
  account = {
    id = "9e36b5cabcd5529d3bd08131b7541c06"
  }
  name = "occultopus.org"
}

resource "cloudflare_zone_setting" "occultopus_org_ssl" {
  zone_id    = cloudflare_zone.occultopus_org.id
  setting_id = "ssl"
  value      = "flexible"
}

resource "cloudflare_zone_setting" "occultopus_org_always_use_https" {
  zone_id    = cloudflare_zone.occultopus_org.id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "occultopus_org_security_header" {
  zone_id    = cloudflare_zone.occultopus_org.id
  setting_id = "security_header"
  value = [{
    enabled            = true
    include_subdomains = true
    preload            = true
    max_age            = 31536000
  }]
}

resource "cloudflare_dns_record" "occultopus_org_cname" {
  for_each = local.occultopus_org_cnames

  zone_id = cloudflare_zone.occultopus_org.id
  name    = "${each.key}.occultopus.org"
  type    = "CNAME"
  content = trimsuffix(each.value, ".")
  ttl     = 1
}
