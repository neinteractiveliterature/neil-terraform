resource "aws_s3_bucket" "neilhosting_net" {
  acl    = "public-read"
  bucket = "neilhosting.net"

  website {
    redirect_all_requests_to = "www.neilhosting.net"
  }
}

locals {
  s3_bucket_origin = "S3-neilhosting.net"
}

resource "aws_acm_certificate" "neilhosting_net" {

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
    viewer_protocol_policy = "allow-all"

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
    acm_certificate_arn = aws_acm_certificate.neilhosting_net.arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method = "sni-only"
  }
}
