provider "aws" {
  profile = "neil"
  region = "us-east-1"
}

resource "aws_s3_bucket" "interconlarp_org" {
  bucket                      = "interconlarp.org"
  acl                         = "public-read"
  website_domain              = "s3-website-us-east-1.amazonaws.com"
  website_endpoint            = "interconlarp.org.s3-website-us-east-1.amazonaws.com"

  versioning {
    enabled    = false
    mfa_delete = false
  }

  website {
    error_document = "error.html"
    index_document = "index.html"
    routing_rules  = jsonencode(
      [
        {
          Condition = {
            KeyPrefixEquals = "policy"
          }
          Redirect  = {
            HostName         = "u.interconlarp.org"
            HttpRedirectCode = "302"
            Protocol         = "https"
            ReplaceKeyWith   = "pages/rules"
          }
        },
        {
          Redirect = {
            HostName         = "u.interconlarp.org"
            HttpRedirectCode = "302"
            Protocol         = "https"
            ReplaceKeyWith   = ""
          }
        },
      ]
    )
  }
}

resource "aws_acm_certificate" "interconlarp_org" {
  domain_name               = "interconlarp.org"
  subject_alternative_names = [
    "www.interconlarp.org",
  ]
}

resource "aws_iam_role" "lambda_edge_role" {
  assume_role_policy    = jsonencode(
    {
      Statement = [
        {
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = {
            Service = [
              "lambda.amazonaws.com",
              "edgelambda.amazonaws.com",
            ]
          }
        },
      ]
      Version   = "2012-10-17"
    }
  )
  path = "/service-role/"
}

resource "aws_lambda_function" "addSecurityHeaders" {
  description   = "Blueprint for modifying CloudFront response header implemented in NodeJS."
  function_name = "arn:aws:lambda:us-east-1:689053117832:function:addSecurityHeaders"
  handler       = "index.handler"
  role          = aws_iam_role.lambda_edge_role.arn
  runtime       = "nodejs10.x"
  timeout       = 1

  tags = {
    "lambda-console:blueprint" = "cloudfront-modify-response-header"
  }
}

locals {
  interconlarp_org_orgin = "S3-interconlarp.org"
}

resource "aws_cloudfront_distribution" "interconlarp_org" {
  enabled = true

  origin {
    domain_name = aws_s3_bucket.interconlarp_org.website_endpoint
    origin_id   = local.interconlarp_org_orgin

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

    # s3_origin_config {
    #   origin_access_identity = "origin-access-identity/cloudfront/ABCDEFG1234567"
    # }
  }

  aliases = [
    "interconlarp.org",
    "www.interconlarp.org"
  ]

  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.interconlarp_org_orgin
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
    acm_certificate_arn = aws_acm_certificate.interconlarp_org.arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method = "sni-only"
  }
}
