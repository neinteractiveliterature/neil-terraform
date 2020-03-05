resource "aws_s3_bucket" "neilhosting_net" {
  acl    = "public-read"
  bucket = "neilhosting.net"

  website {
    redirect_all_requests_to = "https://www.neilhosting.net"
  }
}

locals {
  s3_bucket_origin = "S3-neilhosting.net"
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
    name = aws_cloudfront_distribution.neilhosting_net.domain_name
    zone_id = aws_cloudfront_distribution.neilhosting_net.hosted_zone_id
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

resource "aws_acm_certificate" "neilhosting_net" {
  domain_name = "neilhosting.net"
  validation_method = "DNS"
}

resource "aws_route53_record" "neilhosting_net_cert_validation" {
  name    = aws_acm_certificate.neilhosting_net.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.neilhosting_net.domain_validation_options.0.resource_record_type
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  records = [aws_acm_certificate.neilhosting_net.domain_validation_options.0.resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "neilhosting_net" {
  certificate_arn         = aws_acm_certificate.neilhosting_net.arn
  validation_record_fqdns = [aws_route53_record.neilhosting_net_cert_validation.fqdn]
}

resource "aws_cloudfront_distribution" "neilhosting_net" {
  enabled = true

  origin {
    domain_name = aws_s3_bucket.neilhosting_net.website_endpoint
    origin_id   = local.s3_bucket_origin

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  aliases = ["neilhosting.net"]
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_bucket_origin
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      headers = []
      query_string = false

      cookies {
        forward = "none"
      }
    }

    lambda_function_association {
      event_type = "origin-response"
      include_body = false
      lambda_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.neilhosting_net.arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method = "sni-only"
  }
}
