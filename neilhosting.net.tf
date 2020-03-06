resource "aws_s3_bucket" "neilhosting_net" {
  acl    = "public-read"
  bucket = "neilhosting.net"

  website {
    redirect_all_requests_to = "https://www.neilhosting.net"
  }
}

locals {
  intercode_subdomains = ["www.neilhosting.net", "template.neilhosting.net"]
}

resource "aws_route53_zone" "neilhosting_net" {
  name = "neilhosting.net"
}

resource "aws_route53_record" "neilhosting_net_alias" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "neilhosting.net"
  type = "A"

  alias {
    name = module.neilhosting_net_cloudfront.cloudfront_distribution.domain_name
    zone_id = module.neilhosting_net_cloudfront.cloudfront_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "neilhosting_net_mx" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "neilhosting.net"
  type = "MX"
  ttl = 300
  records = [
    "10 mxa.mailgun.org.",
    "10 mxb.mailgun.org."
  ]
}

resource "aws_route53_record" "neilhosting_net_spf" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "neilhosting.net"
  type = "TXT"
  ttl = 300
  records = ["v=spf1 include:mailgun.org ~all"]
}

resource "aws_route53_record" "neilhosting_net_dkim" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "krs._domainkey.neilhosting.net"
  type = "TXT"
  ttl = 300
  records = ["k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgeXF6lftRwGanqYdLvBYPZpntiZSjRL2jXPO8g9uZuxOiySGifWZIPkIQGzqSjY/BMSg5yFn5x88/rKlqilr7+g+m1sj+8t5l/TYdrzVPg7XKwysSOYKzd8WCBOsEhEay+V7w4h+KsjKB0oFGUMDRe+Cxq1M1NffR8W8rCys3awIDAQAB"]
}

resource "aws_route53_record" "neilhosting_net_amazonses" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "_amazonses.neilhosting.net"
  type = "TXT"
  ttl = 1800
  records = ["LEgL3GeA6W0aInKMomh4M7hIGmfNgWSTPYDZBKtqOtk="]
}

resource "aws_route53_record" "neilhosting_net_email" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "email.neilhosting.net"
  type = "CNAME"
  ttl = 300
  records = ["mailgun.org."]
}

# TODO: refactor to use resource for_each against locals.intercode_subdomains
# once Hashicorp releases a version of Terraform that supports it
resource "aws_route53_record" "neilhosting_net_www" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "www.neilhosting.net"
  type = "CNAME"
  ttl = 300
  records = ["peaceful-tortoise-a9lwi8zf1skj973tyemrono5.herokudns.com."]
}
resource "aws_route53_record" "neilhosting_net_template" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "template.neilhosting.net"
  type = "CNAME"
  ttl = 300
  records = ["peaceful-tortoise-a9lwi8zf1skj973tyemrono5.herokudns.com."]
}

module "neilhosting_net_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name = "neilhosting.net"
  origin_id = "S3-neilhosting.net"
  origin_domain_name = aws_s3_bucket.neilhosting_net.website_endpoint
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}

resource "aws_route53_record" "neilhosting_net_cert_validation" {
  name    = module.neilhosting_net_cloudfront.acm_certificate.domain_validation_options.0.resource_record_name
  type    = module.neilhosting_net_cloudfront.acm_certificate.domain_validation_options.0.resource_record_type
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  records = [module.neilhosting_net_cloudfront.acm_certificate.domain_validation_options.0.resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "neilhosting_net" {
  certificate_arn         = module.neilhosting_net_cloudfront.acm_certificate.arn
  validation_record_fqdns = [aws_route53_record.neilhosting_net_cert_validation.fqdn]
}
