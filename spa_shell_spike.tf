# TEMPORARY: tests serving the Intercode SPA shell and assets from S3 behind CloudFront, with a viewer-request
# CloudFront Function choosing between the bucket (browsers) and Rails (crawlers, via /og-shell). Reachable only at
# the distribution's own cloudfront.net domain. Delete this file, spa_shell_spike_router.js.tftpl and the bucket's
# contents when done. See https://github.com/neinteractiveliterature/intercode/issues/12219.

resource "aws_s3_bucket" "spa_shell_spike" {
  bucket = "intercode2-spa-shell-spike"
}

resource "aws_s3_bucket_public_access_block" "spa_shell_spike" {
  bucket = aws_s3_bucket.spa_shell_spike.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "spa_shell_spike" {
  name                              = "intercode2-spa-shell-spike"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "spa_shell_spike_bucket" {
  statement {
    sid       = "CloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.spa_shell_spike.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.spa_shell_spike.arn]
    }
  }

  # So that a missing key is a 404 rather than a 403
  statement {
    sid       = "CloudFrontList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.spa_shell_spike.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.spa_shell_spike.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "spa_shell_spike" {
  bucket = aws_s3_bucket.spa_shell_spike.id
  policy = data.aws_iam_policy_document.spa_shell_spike_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.spa_shell_spike]
}

resource "aws_cloudfront_function" "spa_shell_spike_router" {
  name    = "intercode2-spa-shell-spike-router"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = templatefile("${path.module}/spa_shell_spike_router.js.tftpl", { rails_host_header = "i.interconlarp.org" })
}

# Keyed on the path query parameter only, so each crawled path caches separately and browsers (which get no query
# string) share one entry per URI. Short TTLs keep the experiment easy to iterate on.
resource "aws_cloudfront_cache_policy" "spa_shell_spike" {
  name        = "intercode2-spa-shell-spike"
  default_ttl = 60
  min_ttl     = 0
  max_ttl     = 300

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config { cookie_behavior = "none" }
    headers_config { header_behavior = "none" }
    query_strings_config {
      query_string_behavior = "whitelist"
      query_strings {
        items = ["path"]
      }
    }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

resource "aws_cloudfront_distribution" "spa_shell_spike" {
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"
  comment         = "TEMPORARY: SPA shell from S3 spike (intercode#12219)"

  origin {
    origin_id                = "bucket"
    domain_name              = aws_s3_bucket.spa_shell_spike.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.spa_shell_spike.id
  }

  origin {
    origin_id   = "rails"
    domain_name = "www.neilhosting.net"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "bucket"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = aws_cloudfront_cache_policy.spa_shell_spike.id
    viewer_protocol_policy = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_shell_spike_router.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "spa_shell_spike" {
  value = {
    bucket              = aws_s3_bucket.spa_shell_spike.bucket
    distribution_domain = aws_cloudfront_distribution.spa_shell_spike.domain_name
  }
}
