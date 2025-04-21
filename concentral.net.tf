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
    "maxicon.concentral.net",
    "maxcon2025.concentral.net"
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


resource "cloudflare_dns_record" "concentral_net_convention_mx" {
  for_each = local.concentral_net_convention_mx_subdomains

  zone_id  = cloudflare_zone.concentral_net.id
  name     = each.value
  type     = "MX"
  content  = "inbound-smtp.us-east-1.amazonaws.com"
  ttl      = 1
  priority = 10
}

resource "cloudflare_dns_record" "concentral_net_convention_events_mx" {
  for_each = local.concentral_net_convention_mx_subdomains

  zone_id  = cloudflare_zone.concentral_net.id
  name     = "events.${each.value}"
  type     = "MX"
  content  = "inbound-smtp.us-east-1.amazonaws.com"
  ttl      = 1
  priority = 10
}

# Having an MX record breaks the wildcard CNAME, so we have to have a specific one for each MX domain
resource "cloudflare_dns_record" "concentral_net_convention_mx_cname" {
  for_each = local.concentral_net_convention_mx_subdomains

  zone_id = cloudflare_zone.concentral_net.id
  name    = each.value
  type    = "CNAME"
  content = "intercode.fly.dev"
  ttl     = 1
}

resource "cloudflare_dns_record" "concentral_net_forwardemail_verification" {
  zone_id = cloudflare_zone.concentral_net.id
  name    = "@"
  type    = "TXT"
  content = "forward-email-site-verification=XhOr28dCAG"
  ttl     = 3600
}
