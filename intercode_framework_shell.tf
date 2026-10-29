# Test setup for serving the framework-mode Intercode shell from S3 (neinteractiveliterature/intercode#12258).
#
# A separate bucket from intercode_assets_bucket.tf: each release upload marks every file under its prefix that the
# new release lacks as obsolete, so two builds sharing a bucket would mark each other's files.
#
# The test distribution has the alias h.interconlarp.org, but DNS for h still points at Fly, so it serves no real
# traffic. To test it, send requests to its cloudfront.net address with the real hostname (CloudFront rejects a Host
# header that isn't one of its aliases, so a Host override on the cloudfront.net name doesn't work):
#
#   curl --resolve h.interconlarp.org:443:$(dig +short <cloudfront.net domain> | head -1) https://h.interconlarp.org/
#
# To roll back, delete this file.
locals {
  # A past convention that is not behind CloudFront, so nothing else holds this alias. Its DNS is not changed here.
  intercode_framework_shell_test_hostname = "h.interconlarp.org"
}

resource "aws_acm_certificate" "intercode_framework_shell_test" {
  domain_name       = local.intercode_framework_shell_test_hostname
  validation_method = "DNS"
}

resource "cloudflare_dns_record" "intercode_framework_shell_test_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.intercode_framework_shell_test.domain_validation_options : dvo.domain_name => {
      name  = trimsuffix(dvo.resource_record_name, ".")
      type  = dvo.resource_record_type
      value = trimsuffix(dvo.resource_record_value, ".")
    }
  }

  zone_id = cloudflare_zone.interconlarp_org.id
  name    = each.value.name
  type    = each.value.type
  content = each.value.value
  ttl     = 60
}

resource "aws_acm_certificate_validation" "intercode_framework_shell_test" {
  certificate_arn         = aws_acm_certificate.intercode_framework_shell_test.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.intercode_framework_shell_test.domain_validation_options : trimsuffix(dvo.resource_record_name, ".")]
}

module "intercode_framework_shell_bucket" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/assets_bucket_intercode?ref=main&depth=1"

  bucket_name    = "intercode2-production-framework-shell"
  retention_days = 30

  # cloudfront_intercode doesn't output the ARN, so build it from the distribution ID.
  cloudfront_distribution_arns = [
    "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${module.intercode_framework_shell_test_cloudfront.distribution_id}"
  ]

  github_repository        = "neinteractiveliterature/intercode"
  github_oidc_provider_arn = module.github-oidc.oidc_provider_arn

  # Release tags, and main so that the "Upload framework-mode build to bucket" workflow can be run by hand.
  github_oidc_subjects = [
    "repo:neinteractiveliterature/intercode:ref:refs/tags/*",
    "repo:neinteractiveliterature/intercode:ref:refs/heads/main",
  ]
}

module "intercode_framework_shell_test_cloudfront" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/cloudfront_intercode?ref=main&depth=1"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name                 = "framework-shell-test"
  rails_origin_domain  = "www.neilhosting.net"
  assets_origin_domain = "assets.neilhosting.net"
  aliases              = [local.intercode_framework_shell_test_hostname]
  acm_certificate_arn  = aws_acm_certificate_validation.intercode_framework_shell_test.certificate_arn

  static_shell_enabled                  = true
  static_shell_bucket_domain_name       = module.intercode_framework_shell_bucket.bucket_regional_domain_name
  static_shell_origin_access_control_id = module.intercode_framework_shell_bucket.origin_access_control_id
}

# These repository variables turn on the intercode release workflow's framework-shell-release job and the CI job that
# builds and pushes the framework image on pushes to main.
resource "github_actions_variable" "intercode_framework_shell_bucket" {
  repository    = github_repository.intercode.name
  variable_name = "FRAMEWORK_SHELL_BUCKET"
  value         = module.intercode_framework_shell_bucket.bucket_name
}

resource "github_actions_variable" "intercode_framework_shell_upload_role_arn" {
  repository    = github_repository.intercode.name
  variable_name = "FRAMEWORK_SHELL_UPLOAD_ROLE_ARN"
  value         = module.intercode_framework_shell_bucket.release_upload_role_arn
}

resource "github_actions_variable" "intercode_build_framework" {
  repository    = github_repository.intercode.name
  variable_name = "BUILD_FRAMEWORK"
  value         = "true"
}

output "intercode_framework_shell_test_domain" {
  description = "cloudfront.net domain of the framework-mode shell test distribution; request it with a convention's Host header."
  value       = module.intercode_framework_shell_test_cloudfront.distribution_domain_name
}
