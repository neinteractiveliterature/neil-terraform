resource "aws_s3_bucket" "gamewrap_interactiveliterature_org" {
  bucket = "gamewrap.interactiveliterature.org"
}

resource "aws_s3_bucket_acl" "gamewrap_interactiveliterature_org" {
  bucket = aws_s3_bucket.gamewrap_interactiveliterature_org.bucket
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "gamewrap_interactiveliterature_org" {
  bucket = aws_s3_bucket.gamewrap_interactiveliterature_org.bucket

  error_document {
    key = "error.html"
  }

  index_document {
    suffix = "index.html"
  }
}

module "gamewrap_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  cloudflare_zone = cloudflare_zone.interactiveliterature_org

  domain_name              = "gamewrap.interactiveliterature.org"
  origin_id                = "S3-gamewrap.interactiveliterature.org"
  default_root_object      = "index.html"
  origin_domain_name       = aws_s3_bucket_website_configuration.gamewrap_interactiveliterature_org.website_endpoint
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}

resource "cloudflare_record" "interactiveliterature_org_gamewrap_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "gamewrap"
  type    = "CNAME"
  proxied = true
  value   = aws_s3_bucket_website_configuration.gamewrap_interactiveliterature_org.website_endpoint
}
