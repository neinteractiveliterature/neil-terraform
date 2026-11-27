# Intercode wildcard domains behind CloudFront whose DNS isn't managed here. Each gets a certificate and a distribution
# of its own, so that one domain's certificate problem can't affect another's.
#
# Whoever manages the domain's DNS adds two records, both unproxied (see the intercode_cloudfront_external_dns output):
#
#   1. The certificate's validation CNAME. It has to stay for the certificate to keep renewing. The apply waits for
#      it, so on a new domain, create the certificate on its own first:
#        tofu apply -target='aws_acm_certificate.intercode_cloudfront_external'
#   2. After the distribution is up, "*" pointed at it instead of intercode.fly.dev. Pointing it back undoes the move.
#
# Fly keeps serving these names to CloudFront, so its certificate and _acme-challenge record stay as they are.
locals {
  intercode_cloudfront_external_domains = toset(["festivalofthelarps.com"])
}

resource "aws_acm_certificate" "intercode_cloudfront_external" {
  for_each = local.intercode_cloudfront_external_domains

  domain_name       = "*.${each.value}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "intercode_cloudfront_external" {
  for_each = local.intercode_cloudfront_external_domains

  certificate_arn = aws_acm_certificate.intercode_cloudfront_external[each.value].arn
}

module "intercode_cloudfront_external" {
  for_each = local.intercode_cloudfront_external_domains
  source   = "github.com/neinteractiveliterature/intercode//terraform/modules/cloudfront_intercode?ref=main&depth=1"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name                = replace(each.value, ".", "-")
  rails_origin_domain = "www.neilhosting.net"
  shared_policies     = local.intercode_cloudfront_shared_policies
  aliases             = ["*.${each.value}"]
  acm_certificate_arn = aws_acm_certificate_validation.intercode_cloudfront_external[each.value].certificate_arn

  # Opening a new connection from CloudFront to Rails adds about 75 ms to an API call, so keep idle ones for longer
  rails_origin_keepalive_timeout = 60

  access_logs_enabled                 = true
  access_log_delivery_destination_arn = module.cloudfront_intercode_logging.delivery_destination_arn

  static_shell_bucket_domain_name       = module.intercode_framework_shell_bucket.bucket_regional_domain_name
  static_shell_origin_access_control_id = module.intercode_framework_shell_bucket.origin_access_control_id
}

output "intercode_cloudfront_external_dns" {
  description = "DNS records to add by hand for each externally managed domain behind CloudFront"
  value = {
    for domain in local.intercode_cloudfront_external_domains : domain => {
      certificate_validation = [
        for dvo in aws_acm_certificate.intercode_cloudfront_external[domain].domain_validation_options :
        "${dvo.resource_record_name} ${dvo.resource_record_type} ${dvo.resource_record_value}"
      ]
      wildcard_cname = "*.${domain} CNAME ${module.intercode_cloudfront_external[domain].distribution_domain_name}"
    }
  }
}
