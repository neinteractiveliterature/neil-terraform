locals {
  uploads_neilhosting_net_origin = "S3-intercode2-production"
}

resource "aws_s3_bucket" "intercode2_production" {
  acl    = "private"
  bucket = "intercode2-production"
}

resource "aws_acm_certificate" "uploads_neilhosting_net" {
  domain_name = "uploads.neilhosting.net"
}

resource "aws_route53_record" "uploads_neilhosting_net_cert_validation" {
  name    = aws_acm_certificate.uploads_neilhosting_net.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.uploads_neilhosting_net.domain_validation_options.0.resource_record_type
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  records = [aws_acm_certificate.uploads_neilhosting_net.domain_validation_options.0.resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "uploads_neilhosting_net" {
  certificate_arn         = aws_acm_certificate.uploads_neilhosting_net.arn
  validation_record_fqdns = [aws_route53_record.uploads_neilhosting_net_cert_validation.fqdn]
}

resource "aws_route53_record" "uploads_neilhosting_net" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "uploads.neilhosting.net"
  type = "CNAME"
  ttl = 300
  records = ["${aws_cloudfront_distribution.uploads_neilhosting_net.domain_name}."]
}

resource "aws_cloudfront_distribution" "uploads_neilhosting_net" {
  enabled = true

  origin {
    domain_name = aws_s3_bucket.intercode2_production.bucket_domain_name
    origin_id   = local.uploads_neilhosting_net_origin
  }

  aliases = ["uploads.neilhosting.net"]
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.uploads_neilhosting_net_origin
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      headers = []
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.uploads_neilhosting_net.arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method = "sni-only"
  }
}
