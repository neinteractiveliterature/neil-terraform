locals {
  intercode_subdomains = ["www.neilhosting.net", "template.neilhosting.net"]
  hosted_org_subdomains = {
    "becon" = "neilhosting.onrender.com.",
    "gbls"  = "neilhosting.onrender.com."
  }
}

resource "aws_route53_zone" "neilhosting_net" {
  name = "neilhosting.net"
}

resource "cloudflare_zone" "neilhosting_net" {
  zone = "neilhosting.net"
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
  records = ["v=spf1 include:amazonses.com ~all"]
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

resource "cloudflare_record" "neilhosting_net_a" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "neilhosting.net"
  type    = "A"
  value   = "216.24.57.1"
}

resource "cloudflare_record" "neilhosting_net_mx" {
  zone_id  = cloudflare_zone.neilhosting_net.id
  name     = "neilhosting.net"
  type     = "MX"
  value    = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
}

resource "cloudflare_record" "neilhosting_net_spf" {
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = "neilhosting.net"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
}

resource "cloudflare_record" "neilhosting_net_intercode" {
  count   = length(local.intercode_subdomains)
  zone_id = cloudflare_zone.neilhosting_net.id
  name    = local.intercode_subdomains[count.index]
  type    = "CNAME"
  value   = "neilhosting.onrender.com"
}

resource "cloudflare_record" "neilhosting_net_hosted_orgs" {
  for_each = local.hosted_org_subdomains
  zone_id  = cloudflare_zone.neilhosting_net.id
  name     = "${each.key}.hosted.neilhosting.net"
  type     = "CNAME"
  value    = trimsuffix(each.value, ".")
}
