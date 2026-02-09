resource "github_repository" "game_wrap" {
  name                 = "game_wrap"
  description          = "The web site for Game Wrap"
  has_issues           = true
  has_projects         = true
  has_wiki             = true
  vulnerability_alerts = true
}

module "gamewrap_sst_github_deployment" {
  source = "./modules/sst_github_deployment"

  app_name = "game-wrap"
  cloudflare_account_id = cloudflare_account.neil.id
  github_repository = github_repository.game_wrap
  oidc_provider_arn = module.github-oidc.oidc_provider_arn
  writable_cloudflare_zones = [cloudflare_zone.interactiveliterature_org]
}
