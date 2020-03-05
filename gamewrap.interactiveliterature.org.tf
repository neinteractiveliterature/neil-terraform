resource "aws_s3_bucket" "gamewrap_interactiveliterature_org" {
  acl    = "public-read"
  bucket = "gamewrap.interactiveliterature.org"
  website_domain   = "s3-website-us-east-1.amazonaws.com"
  website_endpoint = "gamewrap.interactiveliterature.org.s3-website-us-east-1.amazonaws.com"

  website {
    error_document = "error.html"
    index_document = "index.html"
  }
}

resource "aws_acm_certificate" "gamewrap_interactiveliterature_org" {
  domain_name               = "gamewrap.interactiveliterature.org"
}

locals {
  gamewrap_interactiveliterature_org_origin = "S3-gamewrap.interactiveliterature.org"
}

resource "aws_iam_group" "gamewrap_s3" {
  name = "gamewrap-s3"
}

resource "aws_iam_group_policy" "gamewrap_s3" {
  name = "gamewrap-s3"
  group = aws_iam_group.gamewrap_s3.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "bucket",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.gamewrap_interactiveliterature_org.bucket}"
      ]
    },
    {
      "Sid": "objects",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.gamewrap_interactiveliterature_org.bucket}/*"
      ]
    }
  ]
}
  EOF
}

resource "aws_iam_group_policy" "gamewrap_cloudfront" {
  name = "gamewrap-cloudfront"
  group = aws_iam_group.gamewrap_s3.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1545167594000",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateInvalidation",
        "cloudfront:GetDistribution"
      ],
      "Resource": [
        "${aws_cloudfront_distribution.gamewrap_interactiveliterature_org.arn}"
      ]
    }
  ]
}
  EOF
}

resource "aws_iam_user" "gamewrap_s3" {
  name = "gamewrap-s3"
}

resource "aws_iam_user_group_membership" "gamewrap_s3" {
  user = aws_iam_user.gamewrap_s3.name
  groups = [aws_iam_group.gamewrap_s3.name]
}

resource "aws_cloudfront_distribution" "gamewrap_interactiveliterature_org" {
  enabled = true

  origin {
    domain_name = aws_s3_bucket.gamewrap_interactiveliterature_org.website_endpoint
    origin_id   = local.gamewrap_interactiveliterature_org_origin

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  aliases = ["gamewrap.interactiveliterature.org"]
  is_ipv6_enabled = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.gamewrap_interactiveliterature_org_origin
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
    acm_certificate_arn = aws_acm_certificate.gamewrap_interactiveliterature_org.arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method = "sni-only"
  }
}
