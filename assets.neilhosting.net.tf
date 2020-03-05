locals {
  intercode_origin = "intercode"
}

resource "aws_acm_certificate" "assets_neilhosting_net" {
  domain_name               = "assets.neilhosting.net"
}

resource "aws_route53_record" "assets_neilhosting_net_cert_validation" {
  name    = aws_acm_certificate.assets_neilhosting_net.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.assets_neilhosting_net.domain_validation_options.0.resource_record_type
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  records = [aws_acm_certificate.assets_neilhosting_net.domain_validation_options.0.resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "assets_neilhosting_net" {
  certificate_arn         = aws_acm_certificate.assets_neilhosting_net.arn
  validation_record_fqdns = [aws_route53_record.assets_neilhosting_net_cert_validation.fqdn]
}

resource "aws_route53_record" "assets_neilhosting_net" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "assets.neilhosting.net"
  type = "CNAME"
  ttl = 300
  records = ["${aws_cloudfront_distribution.assets_neilhosting_net.domain_name}."]
}

resource "aws_cloudfront_distribution" "assets_neilhosting_net" {
  enabled = true

  origin {
    domain_name = "www.neilhosting.net"
    origin_id   = local.intercode_origin

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  aliases = ["assets.neilhosting.net"]
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.intercode_origin
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
    acm_certificate_arn = aws_acm_certificate.assets_neilhosting_net.arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method = "sni-only"
  }
}
