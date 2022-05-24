resource "cloudflare_zone" "convention_host" {
  zone = "convention.host"
}

locals {
  convention_host_cnames = {
    "*"                             = "neilhosting.onrender.com."
    "_acme-challenge"               = "neilhosting.verify.renderdns.com."
    "_acme-challenge.cyberol"       = "neilhosting.verify.renderdns.com."
    "_acme-challenge.demo"          = "neilhosting.verify.renderdns.com."
    "_acme-challenge.foambrain"     = "neilhosting.verify.renderdns.com."
    "_acme-challenge.gbls"          = "neilhosting.verify.renderdns.com."
    "_acme-challenge.genericon"     = "neilhosting.verify.renderdns.com."
    "_acme-challenge.larpi"         = "neilhosting.verify.renderdns.com."
    "_acme-challenge.slaw"          = "neilhosting.verify.renderdns.com."
    "_acme-challenge.test"          = "neilhosting.verify.renderdns.com."
    "_cf-custom-hostname"           = "neilhosting.hostname.renderdns.com."
    "_cf-custom-hostname.cyberol"   = "neilhosting.hostname.renderdns.com."
    "_cf-custom-hostname.demo"      = "neilhosting.hostname.renderdns.com."
    "_cf-custom-hostname.foambrain" = "neilhosting.hostname.renderdns.com."
    "_cf-custom-hostname.gbls"      = "neilhosting.hostname.renderdns.com."
    "_cf-custom-hostname.genericon" = "neilhosting.hostname.renderdns.com."
    "_cf-custom-hostname.larpi"     = "neilhosting.hostname.renderdns.com."
    "_cf-custom-hostname.slaw"      = "neilhosting.hostname.renderdns.com."
    "_cf-custom-hostname.test"      = "neilhosting.hostname.renderdns.com."
    "*.demo"                        = "neilhosting.onrender.com."
    "*.cyberol"                     = "neilhosting.onrender.com."
    "*.foambrain"                   = "neilhosting.onrender.com."
    "*.gbls"                        = "neilhosting.onrender.com."
    "*.genericon"                   = "neilhosting.onrender.com."
    "*.larpi"                       = "neilhosting.onrender.com."
    "*.slaw"                        = "neilhosting.onrender.com."
    "*.test"                        = "neilhosting.onrender.com."
  }
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
