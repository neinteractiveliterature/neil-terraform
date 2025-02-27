locals {
  intercon_cc_redirects = {
    "covid-precheck" = {
      HostName       = "w.interconlarp.org"
      Protocol       = "https"
      ReplaceKeyWith = "pages/covid-precheck"
    },
    "new-proposal" = {
      HostName       = "x.interconlarp.org"
      Protocol       = "https"
      ReplaceKeyWith = "pages/new-proposal"
    }
  }
}

resource "cloudflare_zone" "intercon_cc" {
  account_id = "9e36b5cabcd5529d3bd08131b7541c06"
  zone       = "intercon.cc"
}

resource "aws_s3_bucket" "intercon_cc" {
  bucket = "intercon.cc"
}

resource "aws_s3_bucket_public_access_block" "intercon_cc" {
  bucket = aws_s3_bucket.intercon_cc.id

  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "intercon_cc" {
  bucket = aws_s3_bucket.intercon_cc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.intercon_cc.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "intercon_cc" {
  bucket = aws_s3_bucket.intercon_cc.bucket
  index_document {
    suffix = "index.html"
  }

  routing_rules = jsonencode(
    concat(
      [
        for key_prefix, redirect in local.intercon_cc_redirects :
        {
          Condition = {
            HttpErrorCodeReturnedEquals = "404"
            KeyPrefixEquals             = key_prefix
          }
          Redirect = redirect
        }
      ],
      [
        {
          Redirect = {
            HostName       = "interconlarp.org"
            Protocol       = "https"
            ReplaceKeyWith = ""
          }
        }
      ]
    )
  )
}

resource "cloudflare_record" "intercon_cc_apex_alias" {
  zone_id = cloudflare_zone.intercon_cc.id
  name    = cloudflare_zone.intercon_cc.zone
  type    = "CNAME"
  proxied = true
  value   = aws_s3_bucket_website_configuration.intercon_cc.website_endpoint
}

resource "cloudflare_record" "www_intercon_cc_cname" {
  zone_id = cloudflare_zone.intercon_cc.id
  name    = "www"
  type    = "CNAME"
  proxied = true
  value   = cloudflare_zone.intercon_cc.zone
}
