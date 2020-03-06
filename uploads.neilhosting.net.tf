resource "aws_route53_record" "uploads_neilhosting_net_cert_validation" {
  name    = module.uploads_neilhosting_net_cloudfront.acm_certificate.domain_validation_options.0.resource_record_name
  type    = module.uploads_neilhosting_net_cloudfront.acm_certificate.domain_validation_options.0.resource_record_type
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  records = [module.uploads_neilhosting_net_cloudfront.acm_certificate.domain_validation_options.0.resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "uploads_neilhosting_net" {
  certificate_arn         = module.uploads_neilhosting_net_cloudfront.acm_certificate.arn
  validation_record_fqdns = [aws_route53_record.uploads_neilhosting_net_cert_validation.fqdn]
}

resource "aws_route53_record" "uploads_neilhosting_net" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "uploads.neilhosting.net"
  type = "CNAME"
  ttl = 300
  records = ["${module.uploads_neilhosting_net_cloudfront.cloudfront_distribution.domain_name}."]
}

module "uploads_neilhosting_net_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name = "uploads.neilhosting.net"
  origin_id = "S3-intercode2-production"
  origin_domain_name = aws_s3_bucket.intercode2_production.bucket_domain_name
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}
