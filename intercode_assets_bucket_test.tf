# TEMPORARY: a throwaway CloudFront distribution in front of the Intercode assets bucket, to check that the bucket
# behaves like the current assets origin before assets.neilhosting.net is repointed at it
# (neinteractiveliterature/intercode#12232). It has no custom domain, so it needs no certificate or DNS. Nothing in
# production uses it.
#
# To try it: apply, then compare responses from the distribution's *.cloudfront.net domain (the
# intercode_assets_test_domain output) with the same paths on assets.neilhosting.net. When done, delete this file; the
# response headers policy is meant to be reused by the real distribution at cutover, so move it rather than
# recreating it. The bucket's cloudfront_distribution_arns in intercode_assets_bucket.tf must list this distribution
# for the bucket to let it read, and the cutover change will replace that entry with the real distribution's ARN.

# The bucket's own CORS configuration only answers requests that carry an Origin header, and this distribution (like
# the current one) caches without Origin in the key, so a first request without one would cache a response with no
# CORS header and break later cross-origin module loads. Adding the header unconditionally matches what Rails and the
# assets nginx do today.
resource "aws_cloudfront_response_headers_policy" "intercode_assets_cors" {
  name    = "intercode-assets-cors"
  comment = "Always allow cross-origin GET/HEAD of Intercode assets, as Rails and the assets nginx do"

  cors_config {
    access_control_allow_credentials = false
    origin_override                  = true

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD"]
    }

    access_control_allow_origins {
      items = ["*"]
    }
  }
}

resource "aws_cloudfront_distribution" "intercode_assets_test" {
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"
  comment         = "TEMPORARY: test of the Intercode assets bucket as a CloudFront origin"

  # CloudFront can list the bucket (it has s3:ListBucket so that a missing file is a 404 rather than a 403), and a
  # request for the bucket root is a listing. With a root object that doesn't exist, "/" is a 404 instead. The real
  # assets distribution needs this too (cloudfront_with_acm's default_root_object).
  default_root_object = "index.html"

  origin {
    origin_id                = "assets-bucket"
    domain_name              = module.intercode_assets_bucket.bucket_regional_domain_name
    origin_access_control_id = module.intercode_assets_bucket.origin_access_control_id
  }

  # Mirrors the behavior of assets.neilhosting.net (cloudfront_with_acm): CachingOptimized, GET/HEAD, compression, and
  # the security headers Lambda@Edge on origin responses. The origin request policy is the S3 equivalent of the
  # CORS-CustomOrigin one it uses.
  default_cache_behavior {
    target_origin_id           = "assets-bucket"
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    origin_request_policy_id   = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # Managed-CORS-S3Origin
    response_headers_policy_id = aws_cloudfront_response_headers_policy.intercode_assets_cors.id

    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    lambda_function_association {
      event_type   = "origin-response"
      include_body = false
      lambda_arn   = aws_lambda_function.addSecurityHeaders.qualified_arn
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

output "intercode_assets_test_domain" {
  description = "Domain of the temporary assets-bucket test distribution."
  value       = aws_cloudfront_distribution.intercode_assets_test.domain_name
}
