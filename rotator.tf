resource "github_repository" "rotator" {
  name                   = "rotator"
  has_issues             = true
  has_projects           = true
  has_wiki               = false
  vulnerability_alerts   = true
  delete_branch_on_merge = true
}

module "rotator_sst_github_deployment" {
  source = "./modules/sst_github_deployment"

  app_name = "rotator"
  cloudflare_account_id = cloudflare_account.neil.id
  github_repository = github_repository.rotator
  oidc_provider_arn = module.github-oidc.oidc_provider_arn
  writable_cloudflare_zones = [cloudflare_zone.interactiveliterature_org]
}

output "rotator_smtp_url" {
  sensitive = true
  value = module.rotator_sst_github_deployment.smtp_url
}
