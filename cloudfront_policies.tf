# One set of CloudFront cache and origin request policies for every cloudfront_intercode distribution. They don't depend
# on the distribution, and an account can only hold 20 cache policies, so each distribution used to cost 5 of them.
module "intercode_cloudfront_policies" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/cloudfront_intercode_policies?ref=main&depth=1"

  name = "intercode-shared"
}

locals {
  intercode_cloudfront_shared_policies = {
    cache_policy_ids          = module.intercode_cloudfront_policies.cache_policy_ids
    origin_request_policy_ids = module.intercode_cloudfront_policies.origin_request_policy_ids
  }
}

# These were the policies of the i.interconlarp.org distribution's own set; they become the shared set.

moved {
  from = module.interconlarp_org_cloudfront_intercode["i"].module.policies[0].aws_cloudfront_origin_request_policy.forward_all
  to   = module.intercode_cloudfront_policies.aws_cloudfront_origin_request_policy.forward_all
}

moved {
  from = module.interconlarp_org_cloudfront_intercode["i"].module.policies[0].aws_cloudfront_origin_request_policy.og_shell
  to   = module.intercode_cloudfront_policies.aws_cloudfront_origin_request_policy.og_shell
}

moved {
  from = module.interconlarp_org_cloudfront_intercode["i"].module.policies[0].aws_cloudfront_cache_policy.no_cache
  to   = module.intercode_cloudfront_policies.aws_cloudfront_cache_policy.no_cache
}

moved {
  from = module.interconlarp_org_cloudfront_intercode["i"].module.policies[0].aws_cloudfront_cache_policy.cdn_spa_shell
  to   = module.intercode_cloudfront_policies.aws_cloudfront_cache_policy.cdn_spa_shell
}

moved {
  from = module.interconlarp_org_cloudfront_intercode["i"].module.policies[0].aws_cloudfront_cache_policy.og_shell
  to   = module.intercode_cloudfront_policies.aws_cloudfront_cache_policy.og_shell
}

moved {
  from = module.interconlarp_org_cloudfront_intercode["i"].module.policies[0].aws_cloudfront_cache_policy.default_router
  to   = module.intercode_cloudfront_policies.aws_cloudfront_cache_policy.default_router
}

moved {
  from = module.interconlarp_org_cloudfront_intercode["i"].module.policies[0].aws_cloudfront_cache_policy.static_shell
  to   = module.intercode_cloudfront_policies.aws_cloudfront_cache_policy.static_shell
}
