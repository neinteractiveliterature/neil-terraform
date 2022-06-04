resource "cloudflare_zone" "concentral_net" {
  zone = "concentral.net"
}

locals {
  concentral_net_cnames = {
    "*"                   = "neilhosting.onrender.com."
    "_acme-challenge"     = "neilhosting.verify.renderdns.com."
    "_cf-custom-hostname" = "neilhosting.hostname.renderdns.com."
    "bridgewater2012"     = "bridgewater2012.concentral.net.s3-website-us-east-1.amazonaws.com."
    "miskatonic2012"      = "miskatonic2012.concentral.net.s3-website-us-east-1.amazonaws.com."
  }

  concentral_net_redirects = {
    "concentral.net"                    = "https://www.concentral.net"
    "dicebubble.concentral.net"         = "https://dicebubble2020.concentral.net"
    "dicebubble5.concentral.net"        = "https://dicebubble2016.concentral.net"
    "molw.concentral.net"               = "https://molw2017.concentral.net"
    "rpitheorycon.concentral.net"       = "https://rpitheorycon2020.concentral.net"
    "spacebubble.concentral.net"        = "https://virtualspacebubble2022.concentral.net"
    "summerlarpin.concentral.net"       = "https://summerlarpin2022.concentral.net"
    "summerlarping.concentral.net"      = "https://summerlarpin2022.concentral.net"
    "timebubble.concentral.net"         = "https://timebubble2021.concentral.net"
    "virtualspacebubble.concentral.net" = "https://virtualspacebubble2022.concentral.net"
    "vsb.concentral.net"                = "https://virtualspacebubble2022.concentral.net"
    "vsb2020.concentral.net"            = "https://virtualspacebubble2020.concentral.net"
  }
}

# For now, the CloudFlare terraform provider doesn't suport bulk redirects.  This has to be managed via
# the web UI at the moment.  This will hopefully change soon.
#
# https://github.com/cloudflare/terraform-provider-cloudflare/issues/1342
resource "cloudflare_record" "concentral_net_apex_redirect" {
  for_each = local.concentral_net_redirects

  zone_id = cloudflare_zone.concentral_net.id
  name    = each.key
  type    = "A"
  value   = "192.0.2.1"
  proxied = true
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
