# Keeps previous Intercode releases' built assets available after each deploy (neinteractiveliterature/intercode#12232).
# Each release uploads its assets here and marks the files it dropped as obsolete; they expire 30 days later.
#
# Nothing serves from this bucket yet: assets.neilhosting.net (module.assets_neilhosting_net_cloudfront) still has
# Rails on Fly as its origin. To cut over, upload a release first, then change that origin to this bucket (using
# bucket_regional_domain_name and origin_access_control_id) and add the distribution's ARN to
# cloudfront_distribution_arns below, so it can read the bucket.
module "intercode_assets_bucket" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/assets_bucket_intercode?ref=main&depth=1"

  bucket_name    = "intercode2-production-assets"
  retention_days = 30

  # Reuse the account's existing GitHub Actions OIDC provider (it can only have one).
  github_repository        = "neinteractiveliterature/intercode"
  github_oidc_provider_arn = module.github-oidc.oidc_provider_arn
}

# Set these as the ASSETS_BUCKET and ASSETS_UPLOAD_ROLE_ARN variables on the intercode GitHub repository to turn on the
# release workflow's upload to the bucket.
output "intercode_assets_bucket_name" {
  description = "Value for the intercode repository's ASSETS_BUCKET variable."
  value       = module.intercode_assets_bucket.bucket_name
}

output "intercode_assets_upload_role_arn" {
  description = "Value for the intercode repository's ASSETS_UPLOAD_ROLE_ARN variable."
  value       = module.intercode_assets_bucket.release_upload_role_arn
}
