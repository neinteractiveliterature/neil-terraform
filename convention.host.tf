resource "cloudflare_zone" "convention_host" {
  zone = "convention.host"
}

locals {
  convention_host_cnames = {
    "*"                   = "neilhosting.onrender.com."
    "_acme-challenge"     = "neilhosting.verify.renderdns.com."
    "_cf-custom-hostname" = "neilhosting.hostname.renderdns.com."
  }

  convention_host_migration_targets = {
    "22.genericon.convention.host"             = "genericon22.concentral.net"
    "23.genericon.convention.host"             = "genericon23.concentral.net"
    "2009.slaw.convention.host"                = "slaw2009.concentral.net"
    "2010.slaw.convention.host"                = "slaw2010.concentral.net"
    "2011.slaw.convention.host"                = "slaw2011.concentral.net"
    "2020.cyberol.convention.host"             = "cyberol2020.concentral.net"
    "becon.demo.convention.host"               = "becon.demo.concentral.net"
    "consequences.demo.convention.host"        = "consequences.demo.concentral.net"
    "davetest.convention.host"                 = "davetest.concentral.net"
    "drums.gbls.convention.host"               = "drums.gbls.concentral.net"
    "fallingstars.convention.host"             = "fallingstars.concentral.net"
    "hrsfanssummerparty-2020.convention.host"  = "hrsfanssummerparty-2020.concentral.net"
    "hrsfanssummerparty-2021.convention.host"  = "hrsfanssummerparty-2021.concentral.net"
    "minigames.larpi.convention.host"          = "larpi-minigames.concentral.net"
    "nov2019.gbls.convention.host"             = "nov2019.gbls.concentral.net"
    "sea.gbls.convention.host"                 = "sea.gbls.concentral.net"
    "templatecon.convention.host"              = "templatecon.concentral.net"
    "weekendofhell4.foambrain.convention.host" = "weekendofhell4.concentral.net"
    "weekendofhell5.foambrain.convention.host" = "weekendofhell5.concentral.net"

    # not yet
    # "wicked-hearts-june-2022.convention.host" = "wicked-hearts-june-2022.concentral.net"
  }
}

module "convention_host_migration_redirect" {
  for_each = local.convention_host_migration_targets

  source = "./modules/cloudfront_apex_redirect"

  # Hack: doing this as a "non-cloudflare domain name" even though it really is a cloudflare domain name,
  # because this module is designed to only work with the apex domain
  cloudflare_zone          = cloudflare_zone.convention_host
  domain_name              = each.key
  redirect_destination     = "https://${each.value}"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  alternative_names        = []
}

# For now, the CloudFlare terraform provider doesn't suport bulk redirects.  This has to be managed via
# the web UI at the moment.  This will hopefully change soon.
#
# https://github.com/cloudflare/terraform-provider-cloudflare/issues/1342
resource "cloudflare_record" "convention_host_apex_redirect" {
  zone_id = cloudflare_zone.convention_host.id
  name    = "convention.host"
  type    = "A"
  value   = "192.0.2.1"
  proxied = true
}

resource "cloudflare_record" "convention_host_cname" {
  for_each = local.convention_host_cnames

  zone_id = cloudflare_zone.convention_host.id
  name    = "${each.key}.convention.host"
  type    = "CNAME"
  value   = trimsuffix(each.value, ".")
}

resource "cloudflare_record" "convention_host_mx" {
  zone_id  = cloudflare_zone.convention_host.id
  name     = "convention.host"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "convention_host_spf" {
  zone_id = cloudflare_zone.convention_host.id
  name    = "convention.host"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
}
