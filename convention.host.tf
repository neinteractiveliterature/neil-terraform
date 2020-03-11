resource "aws_route53_zone" "convention_host" {
  name = "convention.host"
}

locals {
  convention_host_cnames = {
    "*" = "systematic-emu-ece4iltczqislup66je4ug96.herokudns.com."
    "_acme-challenge" = "_acme-challenge.neilhosting.net."
    "_acme-challenge.demo" = "_acme-challenge.neilhosting.net."
    "_acme-challenge.foambrain" = "_acme-challenge.neilhosting.net."
    "_acme-challenge.gbls" = "_acme-challenge.neilhosting.net."
    "_acme-challenge.genericon" = "_acme-challenge.neilhosting.net."
    "_acme-challenge.larpi" = "_acme-challenge.neilhosting.net."
    "_acme-challenge.slaw" = "_acme-challenge.neilhosting.net."
    "_acme-challenge.test" = "_acme-challenge.neilhosting.net."
    "*.demo" = "damp-mountain-qoz1fdoau4kwpcbz1frqh08i.herokudns.com."
    "email" = "mailgun.org."
    "*.foambrain" = "behavioral-hamster-8bzeixz8bd3rt35shsc0p7we.herokudns.com."
    "furniture-test" = "guarded-pinchusion-vxtvyw1enyzcafs3uhvx7x1q.herokudns.com."
    "*.gbls" = "shaped-goldenrod-h9wpryfa8vwjom8lhe1h5ryx.herokudns.com."
    "*.genericon" = "secret-stream-k361oq58pogv6y5zl9113n03.herokudns.com."
    "*.larpi" = "mathematical-lobster-h6pd2t3hxr0hw561vdpwofz8.herokudns.com."
    "*.slaw" = "dimensional-squash-gb4y74648bukgi7jpre5lsvt.herokudns.com."
    "*.test" = "reticulated-stegosaurus-p92f0odjhalcjpbddpg3fbuy.herokudns.com."
  }

  convention_host_cname_keys = keys(local.convention_host_cnames)
}

module "convention_host_cloudfront" {
  source = "./modules/cloudfront_apex_redirect"

  route53_zone = aws_route53_zone.convention_host
  redirect_destination = "https://www.neilhosting.net"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  alternative_names = ["www.convention.host"]
}

resource "aws_route53_record" "convention_host_cname" {
  count = length(local.convention_host_cname_keys)
  zone_id = aws_route53_zone.convention_host.zone_id
  name = "${local.convention_host_cname_keys[count.index]}.convention.host"
  type = "CNAME"
  ttl = 300
  records = [lookup(local.convention_host_cnames, local.convention_host_cname_keys[count.index], null)]
}

resource "aws_route53_record" "convention_host_mx" {
  zone_id = aws_route53_zone.convention_host.zone_id
  name = "convention.host"
  type = "MX"
  ttl = 300
  records = [
    "10 mxa.mailgun.org.",
    "10 mxb.mailgun.org."
  ]
}

resource "aws_route53_record" "convention_host_mailgun_dkim" {
  zone_id = aws_route53_zone.convention_host.zone_id
  name = "smtp._domainkey.convention.host"
  type = "TXT"
  ttl = 300
  records = ["k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDEj5lFIYoEjeIvTrIZ+VJ2YVLPSej+1Cr4HHBaWqmRLw0U9lasioYkognN7LmRn2/fyuTCBeu+YCO2/s2qcHRgnzIMgIiCNVoEX+PSidgaLEh7u/gbL1AID57QG7q9Wndcd7LOV7eYkxk3XBKiTiRx7/Edr5BSbJEQFZ3h7430WQIDAQAB"]
}

resource "aws_route53_record" "convention_host_spf" {
  zone_id = aws_route53_zone.convention_host.zone_id
  name = "convention.host"
  type = "TXT"
  ttl = 300
  records = ["v=spf1 include:mailgun.org include:amazonses.com ~all"]
}
