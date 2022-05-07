locals {
  intercode_subdomains = ["www.neilhosting.net", "template.neilhosting.net"]
  hosted_org_subdomains = {
    "becon" = "horizontal-dove-25tume72wmmlntnd2fo5ezw3.herokudns.com.",
    "gbls"  = "globular-peach-7du7l3c18utuz0kzznip4k0g.herokudns.com."
  }
}

resource "aws_route53_zone" "neilhosting_net" {
  name = "neilhosting.net"
}

resource "aws_route53_record" "neilhosting_net_a" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name    = "neilhosting.net"
  type    = "A"
  ttl     = 300
  records = ["216.24.57.1"]
}

resource "aws_route53_record" "neilhosting_net_mx" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name    = "neilhosting.net"
  type    = "MX"
  ttl     = 300
  records = [
    "10 inbound-smtp.us-east-1.amazonaws.com."
  ]
}

resource "aws_route53_record" "neilhosting_net_spf" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name    = "neilhosting.net"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:mailgun.org include:amazonses.com ~all"]
}

resource "aws_route53_record" "neilhosting_net_dkim" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name    = "krs._domainkey.neilhosting.net"
  type    = "TXT"
  ttl     = 300
  records = ["k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgeXF6lftRwGanqYdLvBYPZpntiZSjRL2jXPO8g9uZuxOiySGifWZIPkIQGzqSjY/BMSg5yFn5x88/rKlqilr7+g+m1sj+8t5l/TYdrzVPg7XKwysSOYKzd8WCBOsEhEay+V7w4h+KsjKB0oFGUMDRe+Cxq1M1NffR8W8rCys3awIDAQAB"]
}

resource "aws_route53_record" "neilhosting_net_email" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name    = "email.neilhosting.net"
  type    = "CNAME"
  ttl     = 300
  records = ["mailgun.org."]
}

resource "aws_route53_record" "neilhosting_net_intercode" {
  count   = length(local.intercode_subdomains)
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name    = local.intercode_subdomains[count.index]
  type    = "CNAME"
  ttl     = 300
  records = ["neilhosting.onrender.com."]
}

resource "aws_route53_record" "neilhosting_net_hosted_orgs" {
  for_each = local.hosted_org_subdomains
  zone_id  = aws_route53_zone.neilhosting_net.zone_id
  name     = "${each.key}.hosted.neilhosting.net"
  type     = "CNAME"
  ttl      = 300
  records  = [each.value]
}
