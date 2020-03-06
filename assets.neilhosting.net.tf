resource "aws_route53_record" "assets_neilhosting_net_cert_validation" {
  name    = module.assets_neilhosting_net_cloudfront.acm_certificate.domain_validation_options.0.resource_record_name
  type    = module.assets_neilhosting_net_cloudfront.acm_certificate.domain_validation_options.0.resource_record_type
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  records = [module.assets_neilhosting_net_cloudfront.acm_certificate.domain_validation_options.0.resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "assets_neilhosting_net" {
  certificate_arn         = module.assets_neilhosting_net_cloudfront.acm_certificate.arn
  validation_record_fqdns = [aws_route53_record.assets_neilhosting_net_cert_validation.fqdn]
}

resource "aws_route53_record" "assets_neilhosting_net" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "assets.neilhosting.net"
  type = "CNAME"
  ttl = 300
  records = ["${module.assets_neilhosting_net_cloudfront.cloudfront_distribution.domain_name}."]
}

module "assets_neilhosting_net_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name = "assets.neilhosting.net"
  origin_id = "intercode"
  origin_domain_name = "www.neilhosting.net"
  origin_protocol_policy = "https-only"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}
