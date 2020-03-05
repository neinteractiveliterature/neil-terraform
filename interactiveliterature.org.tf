locals {
  intercon_letters = [
    "D", "E", "F", "G", "H", "I", "J", # the Chelmsford years, part I
    "K", # that one year in Waltham
    "L", "M", "N", "O", # the Chelmsford years, part II
    "P", # that one year in Framingham
    "Q", "R", "S", "T", "U" # the Warwick years
  ]
}

resource "aws_s3_bucket" "www_interactiveliterature_org" {
  bucket = "www.interactiveliterature.org"
  acl  = "public-read"
  website_domain = "s3-website-us-east-1.amazonaws.com"
  website_endpoint = "www.interactiveliterature.org.s3-website-us-east-1.amazonaws.com"

  website {
    index_document = "index.html"
    routing_rules = jsonencode(
      concat(
        [
          for letter in local.intercon_letters:
          {
            Condition = {
              HttpErrorCodeReturnedEquals = "404"
              KeyPrefixEquals             = letter
            }
            Redirect  = {
              HostName       = "${lower(letter)}.interconlarp.org"
              Protocol       = "https"
              ReplaceKeyWith = ""
            }
          }
        ],
        [
          {
            Condition = {
              HttpErrorCodeReturnedEquals = "404"
              KeyPrefixEquals             = "Wiki"
            }
            Redirect  = {
              HostName       = "drive.google.com"
              Protocol       = "https"
              ReplaceKeyWith = "drive/folders/1cw0RHoDGbtoy2i0YtU1aD3U-ww3rOcNN?usp=sharing"
            }
          },
        ]
      )
    )
  }
}

resource "aws_iam_group" "interactiveliterature_org_admin" {
  name = "interactiveliterature.org-admin"
}

resource "aws_iam_group_policy_attachment" "interactiveliterature_org_admin_change_password" {
  group = aws_iam_group.interactiveliterature_org_admin.name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

resource "aws_iam_group_policy" "interactiveliterature_org_s3" {
  name = "interactiveliterature.org-s3"
  group = aws_iam_group.interactiveliterature_org_admin.name

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
        "arn:aws:s3:::${aws_s3_bucket.www_interactiveliterature_org.bucket}"
      ]
    },
    {
      "Sid": "objects",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.www_interactiveliterature_org.bucket}/*"
      ]
    }
  ]
}
  EOF
}

resource "aws_iam_group_policy" "interactiveliterature_org_cloudfront" {
  name = "interactiveliterature.org-cloudfront"
  group = aws_iam_group.interactiveliterature_org_admin.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1545167594000",
      "Effect": "Allow",
      "Action": [
        "cloudfront:*"
      ],
      "Resource": [
        "${aws_cloudfront_distribution.interactiveliterature_org.arn}"
      ]
    }
  ]
}
  EOF
}

resource "aws_acm_certificate" "interactiveliterature_org" {
  domain_name               = "interactiveliterature.org"
  subject_alternative_names = [
    "www.interactiveliterature.org",
  ]
}

locals {
  interactiveliterature_org_orgin = "S3-Website-www.interactiveliterature.org.s3-website-us-east-1.amazonaws.com"
}

resource "aws_cloudfront_distribution" "interactiveliterature_org" {
  enabled = true

  origin {
    domain_name = aws_s3_bucket.www_interactiveliterature_org.website_endpoint
    origin_id   = local.interactiveliterature_org_orgin

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  aliases = ["interactiveliterature.org", "www.interactiveliterature.org"]
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.interactiveliterature_org_orgin
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
    acm_certificate_arn = aws_acm_certificate.interactiveliterature_org.arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method = "sni-only"
  }
}
