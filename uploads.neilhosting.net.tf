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
  route53_zone_id = aws_route53_zone.neilhosting_net.zone_id
}
