# Keeps previous Intercode releases' built assets available after each deploy (neinteractiveliterature/intercode#12232).
# Each release uploads its assets here and marks the files it dropped as obsolete; they expire 30 days later.
#
# assets.neilhosting.net (module.assets_neilhosting_net_cloudfront) is served from this bucket, through the bucket's
# origin access control. Its distribution has to be listed in cloudfront_distribution_arns below, so that it can read
# the bucket, and needs a root object that doesn't exist (otherwise "/" is a listing of the bucket) and the CORS
# response headers policy at the end of this file.
module "intercode_assets_bucket" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/assets_bucket_intercode?ref=main&depth=1"

  bucket_name    = "intercode2-production-assets"
  retention_days = 30

  cloudfront_distribution_arns = [module.assets_neilhosting_net_cloudfront.cloudfront_distribution.arn]

  # Reuse the account's existing GitHub Actions OIDC provider (it can only have one).
  github_repository        = "neinteractiveliterature/intercode"
  github_oidc_provider_arn = module.github-oidc.oidc_provider_arn

  # Release tags (what the release workflow runs on), and main, so that the "Upload assets to bucket" workflow can be
  # run by hand to upload an already-built commit. Giving a value here replaces the module's default of tags only.
  github_oidc_subjects = [
    "repo:neinteractiveliterature/intercode:ref:refs/tags/*",
    "repo:neinteractiveliterature/intercode:ref:refs/heads/main",
  ]
}

# These two repository variables turn on the release workflow's upload to the bucket (its assets-bucket-release job is
# skipped while ASSETS_BUCKET is unset), so applying them starts uploads with the next intercode release. Delete
# ASSETS_BUCKET to turn the uploads off.
resource "github_actions_variable" "intercode_assets_bucket" {
  repository    = github_repository.intercode.name
  variable_name = "ASSETS_BUCKET"
  value         = module.intercode_assets_bucket.bucket_name
}

resource "github_actions_variable" "intercode_assets_upload_role_arn" {
  repository    = github_repository.intercode.name
  variable_name = "ASSETS_UPLOAD_ROLE_ARN"
  value         = module.intercode_assets_bucket.release_upload_role_arn
}

output "intercode_assets_bucket_name" {
  description = "Value for the intercode repository's ASSETS_BUCKET variable."
  value       = module.intercode_assets_bucket.bucket_name
}

output "intercode_assets_upload_role_arn" {
  description = "Value for the intercode repository's ASSETS_UPLOAD_ROLE_ARN variable."
  value       = module.intercode_assets_bucket.release_upload_role_arn
}

# CORS for the assets distribution. CloudFront adds the header on every response, cache hits included, whereas the
# bucket's own CORS configuration only answers requests that carry an Origin header, and the distribution caches without
# Origin in the key, so a hit on an object first cached without one would have no CORS header. Sending it for every
# origin and method matches what Rails and the assets nginx did before.
resource "aws_cloudfront_response_headers_policy" "intercode_assets_cors" {
  name    = "intercode-assets-cors"
  comment = "Always allow cross-origin GET/HEAD of Intercode assets, as Rails and the assets nginx do"

  cors_config {
    access_control_allow_credentials = false
    origin_override                  = true

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD"]
    }

    access_control_allow_origins {
      items = ["*"]
    }
  }
}
