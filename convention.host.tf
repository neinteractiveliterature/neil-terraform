resource "aws_route53_zone" "convention_host" {
  name = "convention.host"
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
    "email"                         = "mailgun.org."
    "*.cyberol"                     = "neilhosting.onrender.com."
    "*.foambrain"                   = "neilhosting.onrender.com."
    "furniture-test"                = "guarded-pinchusion-vxtvyw1enyzcafs3uhvx7x1q.herokudns.com."
    "*.gbls"                        = "neilhosting.onrender.com."
    "*.genericon"                   = "neilhosting.onrender.com."
    "*.larpi"                       = "neilhosting.onrender.com."
    "*.slaw"                        = "neilhosting.onrender.com."
    "*.test"                        = "neilhosting.onrender.com."
  }
}

module "convention_host_cloudfront" {
  source = "./modules/cloudfront_apex_redirect"

  route53_zone             = aws_route53_zone.convention_host
  redirect_destination     = "https://www.neilhosting.net"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  alternative_names        = ["www.convention.host"]
}

resource "aws_route53_record" "convention_host_cname" {
  for_each = local.convention_host_cnames

  zone_id = aws_route53_zone.convention_host.zone_id
  name    = "${each.key}.convention.host"
  type    = "CNAME"
  ttl     = 300
  records = [each.value]
}

resource "aws_route53_record" "convention_host_mx" {
  zone_id = aws_route53_zone.convention_host.zone_id
  name    = "convention.host"
  type    = "MX"
  ttl     = 300
  records = [
    "10 inbound-smtp.us-east-1.amazonaws.com."
  ]
}

resource "aws_route53_record" "convention_host_mailgun_dkim" {
  zone_id = aws_route53_zone.convention_host.zone_id
  name    = "smtp._domainkey.convention.host"
  type    = "TXT"
  ttl     = 300
  records = ["k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDEj5lFIYoEjeIvTrIZ+VJ2YVLPSej+1Cr4HHBaWqmRLw0U9lasioYkognN7LmRn2/fyuTCBeu+YCO2/s2qcHRgnzIMgIiCNVoEX+PSidgaLEh7u/gbL1AID57QG7q9Wndcd7LOV7eYkxk3XBKiTiRx7/Edr5BSbJEQFZ3h7430WQIDAQAB"]
}

resource "aws_route53_record" "convention_host_spf" {
  zone_id = aws_route53_zone.convention_host.zone_id
  name    = "convention.host"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:mailgun.org include:amazonses.com ~all"]
}
