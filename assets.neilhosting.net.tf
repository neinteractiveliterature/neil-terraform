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
  route53_zone_id = aws_route53_zone.neilhosting_net.zone_id
}
