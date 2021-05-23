variable "redirect_destination" {
  type = string
}

variable "add_security_headers_arn" {
  type = string
}

variable "validation_method" {
  type = string
  default = "DNS"
}

variable "alternative_names" {
  type = list(string)
  default = []
}

variable "route53_zone" {
  type = object({
    zone_id = string
    name = string
  })
  default = null
}

variable "non_route53_domain_name" {
  type = string
  default = null
}

locals {
  domain_name = var.route53_zone != null ? trimsuffix(var.route53_zone.name, ".") : var.non_route53_domain_name
}

resource "aws_s3_bucket" "redirect_bucket" {
  acl    = "public-read"
  bucket = local.domain_name

  website {
    redirect_all_requests_to = var.redirect_destination
  }
}

resource "aws_route53_record" "apex_alias" {
  count   = var.route53_zone != null ? 1 : 0

  zone_id = var.route53_zone.zone_id
  name = local.domain_name
  type = "A"

  alias {
    name = module.apex_redirect_cloudfront.cloudfront_distribution.domain_name
    zone_id = module.apex_redirect_cloudfront.cloudfront_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alternative_name_cname" {
  count = var.route53_zone != null ? length(var.alternative_names) : 0
  zone_id = var.route53_zone.zone_id
  name = var.alternative_names[count.index]
  type = "CNAME"
  ttl = 300
  records = ["${var.route53_zone.name}."]
}

module "apex_redirect_cloudfront" {
  source = "../cloudfront_with_acm"

  domain_name = local.domain_name
  origin_id = "S3-${local.domain_name}"
  origin_domain_name = aws_s3_bucket.redirect_bucket.website_endpoint
  add_security_headers_arn = var.add_security_headers_arn
  route53_zone = var.route53_zone
  validation_method = var.validation_method
  alternative_names = var.alternative_names
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

output "cert_validation_records" {
  value = module.apex_redirect_cloudfront.cert_validation_records
}

output "redirect_bucket" {
  value = aws_s3_bucket.redirect_bucket
}

output "apex_alias_record" {
  value = aws_route53_record.apex_alias
}
