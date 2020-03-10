variable "domain_name" {
  type = string
}

variable "redirect_destination" {
  type = string
}

variable "add_security_headers_arn" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

resource "aws_s3_bucket" "redirect_bucket" {
  acl    = "public-read"
  bucket = var.domain_name

  website {
    redirect_all_requests_to = var.redirect_destination
  }
}

resource "aws_route53_record" "apex_alias" {
  zone_id = var.route53_zone_id
  name = var.domain_name
  type = "A"

  alias {
    name = module.apex_redirect_cloudfront.cloudfront_distribution.domain_name
    zone_id = module.apex_redirect_cloudfront.cloudfront_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

module "apex_redirect_cloudfront" {
  source = "../cloudfront_with_acm"

  domain_name = var.domain_name
  origin_id = "S3-${var.domain_name}"
  origin_domain_name = aws_s3_bucket.redirect_bucket.website_endpoint
  add_security_headers_arn = var.add_security_headers_arn
  route53_zone_id = var.route53_zone_id
}

output "cloudfront_distribution" {
  value = module.apex_redirect_cloudfront.cloudfront_distribution
}

output "acm_certificate" {
  value = module.apex_redirect_cloudfront.acm_certificate
}

output "cert_validation" {
  value = module.apex_redirect_cloudfront.cert_validation
}

output "cert_validation_record" {
  value = module.apex_redirect_cloudfront.cert_validation_record
}

output "redirect_bucket" {
  value = aws_s3_bucket.redirect_bucket
}

output "apex_alias_record" {
  value = aws_route53_record.apex_alias
}
