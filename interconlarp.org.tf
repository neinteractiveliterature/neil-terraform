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

module "interconlarp_org_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name = "interconlarp.org"
  alternative_names = ["www.interconlarp.org"]
  validation_method = "NONE"
  origin_id = "S3-interconlarp.org"
  origin_domain_name = aws_s3_bucket.interconlarp_org.website_endpoint
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}
