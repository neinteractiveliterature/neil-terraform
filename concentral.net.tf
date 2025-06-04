locals {
  concentral_net_cnames = {
    "*"                    = "intercode.fly.dev"
    "*.demo"               = "intercode.fly.dev"
    "*.gbls"               = "intercode.fly.dev"
    "_acme-challenge"      = "concentral.net.j2o5oe.flydns.net"
    "_acme-challenge.demo" = "demo.concentral.net.j2o5oe.flydns.net"
    "_acme-challenge.gbls" = "gbls.concentral.net.j2o5oe.flydns.net"
    "bridgewater2012"      = "bridgewater2012.concentral.net.s3-website-us-east-1.amazonaws.com."
    "miskatonic2012"       = "miskatonic2012.concentral.net.s3-website-us-east-1.amazonaws.com."
  }

  concentral_net_redirects = {
    "concentral.net"                    = "www.concentral.net"
    "dicebubble.concentral.net"         = "dicebubble2024.concentral.net"
    "dicebubble5.concentral.net"        = "dicebubble2016.concentral.net"
    "maxicon.concentral.net"            = "maxicon2025.concentral.net"
    "molw.concentral.net"               = "molw2017.concentral.net"
    "rpitheorycon.concentral.net"       = "rpitheorycon2020.concentral.net"
    "spacebubble.concentral.net"        = "virtualspacebubble2023.concentral.net"
    "summerlarpin.concentral.net"       = "summerlarpin2025.concentral.net"
    "summerlarping.concentral.net"      = "summerlarpin2025.concentral.net"
    "tapestries2025.concentral.net"     = "2025.tapestrieslarp.org"
    "timebubble.concentral.net"         = "timebubble2025.concentral.net"
    "virtualspacebubble.concentral.net" = "virtualspacebubble2023.concentral.net"
    "vsb.concentral.net"                = "virtualspacebubble2023.concentral.net"
    "vsb2020.concentral.net"            = "virtualspacebubble2020.concentral.net"
    "writersblock.concentral.net"       = "writersblock2024.concentral.net"
  }

  concentral_net_convention_mx_subdomains = toset([
    "alarpfestival-2024",
    "alarpfestival-2025",
    "cyberol2020",
    "hrsfanssummerparty-2020",
    "hrsfanssummerparty-2021",
    "jennylarps",
    "summerlarpin2020",
    "summerlarpin2021",
    "summerlarpin2022",
    "summerlarpin2023",
    "tidalpull2023",
    "tidalpull2025"
  ])
}

resource "cloudflare_zone" "concentral_net" {
  account = {
    id = "9e36b5cabcd5529d3bd08131b7541c06"
  }
  name = "concentral.net"
}

resource "cloudflare_zone_setting" "concentral_net_ssl" {
  zone_id    = cloudflare_zone.concentral_net.id
  setting_id = "ssl"
  value      = "flexible"
}

resource "cloudflare_zone_setting" "concentral_net_always_use_https" {
  zone_id    = cloudflare_zone.concentral_net.id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "concentral_net_security_header" {
  zone_id    = cloudflare_zone.concentral_net.id
  setting_id = "security_header"
  value = [{
    enabled            = true
    include_subdomains = true
    preload            = true
    max_age            = 31536000
  }]
}

module "concentral_net_apex_redirect" {
  for_each = local.concentral_net_redirects

  source = "./modules/cloudflare_apex_redirect"

  cloudflare_zone               = cloudflare_zone.concentral_net
  domain_name                   = each.key
  redirect_destination_hostname = each.value
  redirect_destination_protocol = "https"
  alternative_names             = []
}

resource "cloudflare_dns_record" "concentral_net_cname" {
  for_each = local.concentral_net_cnames

  zone_id = cloudflare_zone.concentral_net.id
  name    = "${each.key}.concentral.net"
  type    = "CNAME"
  content = trimsuffix(each.value, ".")
  ttl     = 1
}

module "concentral_net_forwardemail_receiving_domain" {
  source = "./modules/forwardemail_receiving_domain"

  cloudflare_zone   = cloudflare_zone.concentral_net
  name              = "concentral.net"
  verification_code = local.forwardemail_verification_records_by_domain["concentral.net"]
}

module "concentral_net_convention_mx_forwardemail_receiving_domain" {
  for_each = setintersection(
    keys(local.forwardemail_verification_records_by_domain),
    [for subdomain in local.concentral_net_convention_mx_subdomains : "${subdomain}.concentral.net"]
  )
  source = "./modules/forwardemail_receiving_domain"

  cloudflare_zone   = cloudflare_zone.concentral_net
  name              = each.value
  verification_code = local.forwardemail_verification_records_by_domain[each.value]
}

module "concentral_net_convention_mx_events_forwardemail_receiving_domain" {
  for_each = setintersection(
    keys(local.forwardemail_verification_records_by_domain),
    [for subdomain in local.concentral_net_convention_mx_subdomains : "events.${subdomain}.concentral.net"]
  )
  source = "./modules/forwardemail_receiving_domain"

  cloudflare_zone   = cloudflare_zone.concentral_net
  name              = each.value
  verification_code = local.forwardemail_verification_records_by_domain[each.value]
}

# Having an MX record breaks the wildcard CNAME, so we have to have a specific A record for each MX domain
resource "cloudflare_dns_record" "concentral_net_convention_mx_a" {
  for_each = local.concentral_net_convention_mx_subdomains

  zone_id = cloudflare_zone.concentral_net.id
  name    = "${each.value}.concentral.net"
  type    = "A"
  content = "137.66.59.126"
  ttl     = 1
}

resource "cloudflare_dns_record" "concentral_net_convention_subdomain_aaaa" {
  for_each = local.concentral_net_convention_mx_subdomains

  zone_id = cloudflare_zone.concentral_net.id
  name    = "${each.value}.concentral.net"
  type    = "AAAA"
  content = "2a09:8280:1::4e:bee4"
  ttl     = 1
}
