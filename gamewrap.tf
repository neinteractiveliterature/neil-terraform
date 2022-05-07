resource "aws_s3_bucket" "gamewrap_interactiveliterature_org" {
  acl              = "public-read"
  bucket           = "gamewrap.interactiveliterature.org"
  website_domain   = "s3-website-us-east-1.amazonaws.com"
  website_endpoint = "gamewrap.interactiveliterature.org.s3-website-us-east-1.amazonaws.com"

  website {
    error_document = "error.html"
    index_document = "index.html"
  }
}

module "gamewrap_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  cloudflare_zone = {
    zone_id = cloudflare_zone.interactiveliterature_org.id
  }

  # TODO: remove this once we're actually using CloudFlare DNS for this domain
  validation_method = "EMAIL"

  domain_name              = "gamewrap.interactiveliterature.org"
  origin_id                = "S3-gamewrap.interactiveliterature.org"
  default_root_object      = "index.html"
  origin_domain_name       = aws_s3_bucket.gamewrap_interactiveliterature_org.website_endpoint
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}

resource "cloudflare_record" "interactiveliterature_org_gamewrap_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "gamewrap"
  type    = "CNAME"
  value   = module.gamewrap_cloudfront.cloudfront_distribution.domain_name
}
