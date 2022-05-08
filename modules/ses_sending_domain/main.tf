terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.72"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

variable "route53_zone" {
  type = object({
    zone_id = string
    name    = string
  })
  default = null
}

variable "cloudflare_zone" {
  type = object({
    id   = string
    zone = string
  })
  default = null
}

locals {
  domain_name = trimsuffix(var.cloudflare_zone != null ? var.cloudflare_zone.zone : var.route53_zone.name, ".")
}

resource "aws_ses_domain_identity" "domain_identity" {
  domain = local.domain_name
}

resource "aws_ses_domain_dkim" "domain_dkim" {
  domain = local.domain_name
}

resource "aws_route53_record" "amazonses_verification_record" {
  count = var.route53_zone != null ? 1 : 0

  zone_id = var.route53_zone.zone_id
  name    = "_amazonses.${local.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.domain_identity.verification_token]
}

resource "cloudflare_record" "amazonses_verification_record" {
  count = var.cloudflare_zone != null ? 1 : 0

  zone_id = var.cloudflare_zone.id
  name    = "_amazonses.${local.domain_name}"
  type    = "TXT"
  value   = aws_ses_domain_identity.domain_identity.verification_token
}

resource "aws_route53_record" "amazonses_dkim_record" {
  count = var.route53_zone != null ? 3 : 0

  zone_id = var.route53_zone.zone_id
  name    = "${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, count.index)}._domainkey.${aws_ses_domain_dkim.domain_dkim.domain}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

resource "cloudflare_record" "amazonses_dkim_record" {
  count = var.cloudflare_zone != null ? 3 : 0

  zone_id = var.cloudflare_zone.id
  name    = "${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, count.index)}._domainkey.${aws_ses_domain_dkim.domain_dkim.domain}"
  type    = "CNAME"
  value   = "${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, count.index)}.dkim.amazonses.com"
}
