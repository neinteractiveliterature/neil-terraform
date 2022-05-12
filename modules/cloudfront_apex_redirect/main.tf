terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.72"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

variable "redirect_destination" {
  type = string
}

variable "add_security_headers_arn" {
  type = string
}

variable "validation_method" {
  type    = string
  default = "DNS"
}

variable "alternative_names" {
  type    = list(string)
  default = []
}

variable "cloudflare_zone" {
  type = object({
    id   = string
    zone = string
  })
  default = null
}

variable "non_cloudflare_domain_name" {
  type    = string
  default = null
}

locals {
  domain_name = (
    var.cloudflare_zone != null ?
    var.cloudflare_zone.zone :
    var.non_cloudflare_domain_name
  )
}

resource "aws_s3_bucket" "redirect_bucket" {
  acl    = "public-read"
  bucket = local.domain_name

  website {
    redirect_all_requests_to = var.redirect_destination
  }
}

resource "cloudflare_record" "apex_alias" {
  count = var.cloudflare_zone != null ? 1 : 0

  zone_id = var.cloudflare_zone.id
  name    = local.domain_name
  type    = "CNAME"
  proxied = false
  value   = module.apex_redirect_cloudfront.cloudfront_distribution.domain_name
}

resource "cloudflare_record" "alternative_name_cname" {
  count   = var.cloudflare_zone != null ? length(var.alternative_names) : 0
  zone_id = var.cloudflare_zone.id
  name    = var.alternative_names[count.index]
  type    = "CNAME"
  value   = var.cloudflare_zone.zone
}

module "apex_redirect_cloudfront" {
  source = "../cloudfront_with_acm"

  domain_name              = local.domain_name
  origin_id                = "S3-${local.domain_name}"
  origin_domain_name       = aws_s3_bucket.redirect_bucket.website_endpoint
  add_security_headers_arn = var.add_security_headers_arn
  cloudflare_zone          = var.cloudflare_zone
  validation_method        = var.validation_method
  alternative_names        = var.alternative_names
  compress                 = false
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
  value = cloudflare_record.apex_alias
}
