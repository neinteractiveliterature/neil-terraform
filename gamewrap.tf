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

resource "cloudflare_record" "interactiveliterature_org_gamewrap_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "gamewrap"
  type    = "CNAME"
  proxied = true
  value   = aws_s3_bucket_website_configuration.gamewrap_interactiveliterature_org.website_endpoint
}
