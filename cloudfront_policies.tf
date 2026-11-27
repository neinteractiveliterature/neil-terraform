# One set of CloudFront cache and origin request policies for every cloudfront_intercode distribution. They don't depend
# on the distribution, and an account can only hold 20 cache policies, so each distribution used to cost 5 of them.
module "intercode_cloudfront_policies" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/cloudfront_intercode_policies?ref=main&depth=1"

  name = "intercode-shared"

  # The release gives index.html stale-while-revalidate=300, and CloudFront cuts that window off at this maximum.
  static_shell_max_ttl = 300
}

locals {
  intercode_cloudfront_shared_policies = {
    cache_policy_ids          = module.intercode_cloudfront_policies.cache_policy_ids
    origin_request_policy_ids = module.intercode_cloudfront_policies.origin_request_policy_ids
  }
}
