resource "cloudflare_zone" "concentral_net" {
  account_id = "9e36b5cabcd5529d3bd08131b7541c06"
  zone       = "concentral.net"
}

locals {
  concentral_net_cnames = {
    "*"                    = heroku_domain.intercode["*.concentral.net"].cname
    "*.demo"               = heroku_domain.intercode["*.demo.concentral.net"].cname
    "*.gbls"               = heroku_domain.intercode["*.gbls.concentral.net"].cname
    "_acme-challenge"      = "_acme-challenge.neilhosting.net."
    "_acme-challenge.demo" = "_acme-challenge.neilhosting.net."
    "_acme-challenge.gbls" = "_acme-challenge.neilhosting.net."
    "bridgewater2012"      = "bridgewater2012.concentral.net.s3-website-us-east-1.amazonaws.com."
    "miskatonic2012"       = "miskatonic2012.concentral.net.s3-website-us-east-1.amazonaws.com."
  }

  concentral_net_redirects = {
    "concentral.net"                    = "www.concentral.net"
    "dicebubble.concentral.net"         = "dicebubble2024.concentral.net"
    "dicebubble5.concentral.net"        = "dicebubble2016.concentral.net"
    "molw.concentral.net"               = "molw2017.concentral.net"
    "rpitheorycon.concentral.net"       = "rpitheorycon2020.concentral.net"
    "spacebubble.concentral.net"        = "virtualspacebubble2023.concentral.net"
    "summerlarpin.concentral.net"       = "summerlarpin2023.concentral.net"
    "summerlarping.concentral.net"      = "summerlarpin2023.concentral.net"
    "timebubble.concentral.net"         = "timebubble2023.concentral.net"
    "virtualspacebubble.concentral.net" = "virtualspacebubble2023.concentral.net"
    "vsb.concentral.net"                = "virtualspacebubble2023.concentral.net"
    "vsb2020.concentral.net"            = "virtualspacebubble2020.concentral.net"
  }

  concentral_net_convention_mx_subdomains = toset([
    "maxicon.concentral.net"
  ])
}

module "concentral_net_apex_redirect" {
  for_each = local.concentral_net_redirects

  source = "./modules/cloudfront_apex_redirect"

  cloudflare_zone               = cloudflare_zone.concentral_net
  domain_name                   = each.key
  redirect_destination_hostname = each.value
  redirect_destination_protocol = "https"
  add_security_headers_arn      = aws_lambda_function.addSecurityHeaders.qualified_arn
  alternative_names             = []
}

resource "cloudflare_record" "concentral_net_cname" {
  for_each = local.concentral_net_cnames

  zone_id = cloudflare_zone.concentral_net.id
  name    = "${each.key}.concentral.net"
  type    = "CNAME"
  value   = trimsuffix(each.value, ".")
}

resource "cloudflare_record" "concentral_net_mx" {
  zone_id  = cloudflare_zone.concentral_net.id
  name     = "concentral.net"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "concentral_net_spf" {
  zone_id = cloudflare_zone.concentral_net.id
  name    = "concentral.net"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
}

resource "cloudflare_record" "concentral_net_convention_mx" {
  for_each = local.concentral_net_convention_mx_subdomains

  zone_id  = cloudflare_zone.concentral_net.id
  name     = each.value
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "concentral_net_convention_events_mx" {
  for_each = local.concentral_net_convention_mx_subdomains

  zone_id  = cloudflare_zone.concentral_net.id
  name     = "events.${each.value}"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

# Having an MX record breaks the wildcard CNAME, so we have to have a specific one for each MX domain
resource "cloudflare_record" "concentral_net_convention_mx_cname" {
  for_each = local.concentral_net_convention_mx_subdomains

  zone_id = cloudflare_zone.concentral_net.id
  name    = each.value
  type    = "CNAME"
  value   = heroku_domain.intercode["*.concentral.net"].cname
}
