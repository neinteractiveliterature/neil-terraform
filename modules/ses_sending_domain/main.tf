variable "route53_zone" {
  type = object({
    zone_id = string
    name = string
  })
}

locals {
  domain_name = trimsuffix(var.route53_zone.name, ".")
}

resource "aws_ses_domain_identity" "domain_identity" {
  domain = local.domain_name
}

resource "aws_ses_domain_dkim" "domain_dkim" {
  domain = local.domain_name
}

resource "aws_route53_record" "amazonses_verification_record" {
  zone_id = var.route53_zone.zone_id
  name = "_amazonses.${local.domain_name}"
  type = "TXT"
  ttl = 600
  records = [aws_ses_domain_identity.domain_identity.verification_token]
}

resource "aws_route53_record" "amazonses_dkim_record" {
  count   = 3
  zone_id = var.route53_zone.zone_id
  name    = "${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, count.index)}._domainkey.${aws_ses_domain_dkim.domain_dkim.domain}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, count.index)}.dkim.amazonses.com"]
}
