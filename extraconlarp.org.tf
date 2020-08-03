module "extraconlarp_org_cloudfront" {
  source = "./modules/cloudfront_apex_redirect"

  route53_zone = null
  non_route53_domain_name = "extraconlarp.org"
  redirect_destination = "https://2021.extraconlarp.org"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  alternative_names = ["www.extraconlarp.org"]
}
