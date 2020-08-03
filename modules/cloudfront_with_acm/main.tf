variable "origin_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "alternative_names" {
  type = list(string)
  default = []
}

variable "validation_method" {
  type = string
  default = "DNS"
}

variable "origin_domain_name" {
  type = string
}

variable "origin_protocol_policy" {
  type = string
  default = "http-only"
}

variable "default_root_object" {
  type = string
  default = null
}

variable "add_security_headers_arn" {
  type = string
}

variable "route53_zone" {
  type = object({
    zone_id = string
  })
  default = null
}

resource "aws_acm_certificate" "cloudfront_cert" {
  domain_name = var.domain_name
  validation_method = var.validation_method
  subject_alternative_names = var.alternative_names

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }
}

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  enabled = true

  origin {
    domain_name = var.origin_domain_name
    origin_id   = var.origin_id

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = var.origin_protocol_policy
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  aliases = concat([var.domain_name], var.alternative_names)
  is_ipv6_enabled = true
  default_root_object = var.default_root_object

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.origin_id
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
      lambda_arn = var.add_security_headers_arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cloudfront_cert.arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method = "sni-only"
  }
}

resource "aws_acm_certificate_validation" "cert_validation" {
  count   = var.route53_zone != null ? 1 : 0

  certificate_arn         = aws_acm_certificate.cloudfront_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_records : record.fqdn]
}

resource "aws_route53_record" "cert_validation_records" {
  count   = var.route53_zone != null ? length(aws_acm_certificate.cloudfront_cert.domain_validation_options) : 0

  name    = aws_acm_certificate.cloudfront_cert.domain_validation_options[count.index].resource_record_name
  type    = aws_acm_certificate.cloudfront_cert.domain_validation_options[count.index].resource_record_type
  zone_id = var.route53_zone.zone_id
  records = [aws_acm_certificate.cloudfront_cert.domain_validation_options[count.index].resource_record_value]
  ttl     = 300
}

output "cloudfront_distribution" {
  value = aws_cloudfront_distribution.cloudfront_distribution
}

output "acm_certificate" {
  value = aws_acm_certificate.cloudfront_cert
}

output "cert_validation" {
  value = (
    length(aws_acm_certificate_validation.cert_validation) > 0
    ? aws_acm_certificate_validation.cert_validation[0]
    : null
  )
}

output "cert_validation_records" {
  value = aws_route53_record.cert_validation_records
}
