# The bucket that serves the Intercode frontend to the CloudFront distributions.
#
# A separate bucket from intercode_assets_bucket.tf: each release upload marks every file under its prefix that the
# new release lacks as obsolete, so two builds sharing a bucket would mark each other's files.
module "intercode_framework_shell_bucket" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/assets_bucket_intercode?ref=main&depth=1"

  bucket_name    = "intercode2-production-framework-shell"
  retention_days = 30

  allow_account_cloudfront_distributions = true

  github_repository        = "neinteractiveliterature/intercode"
  github_oidc_provider_arn = module.github-oidc.oidc_provider_arn

  # Release tags, and main so that the "Upload framework-mode build to bucket" workflow can be run by hand.
  github_oidc_subjects = [
    "repo:neinteractiveliterature/intercode:ref:refs/tags/*",
    "repo:neinteractiveliterature/intercode:ref:refs/heads/main",
  ]
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
