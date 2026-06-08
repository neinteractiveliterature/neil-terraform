resource "github_repository" "game_wrap" {
  name                 = "game_wrap"
  description          = "The web site for Game Wrap"
  has_issues           = true
  has_projects         = true
  has_wiki             = true
}

resource "github_repository_vulnerability_alerts" "game_wrap" {
  repository = github_repository.game_wrap.name
}

module "gamewrap_sst_github_deployment" {
  source = "github.com/neinteractiveliterature/neil-terraform-modules//sst_github_deployment?ref=main"

  app_name = "game-wrap"
  cloudflare_account_id = cloudflare_account.neil.id
  github_repository = {
    name      = github_repository.game_wrap.name
    full_name = github_repository.game_wrap.full_name
  }
  oidc_provider_arn = module.github-oidc.oidc_provider_arn
  writable_cloudflare_zones = [cloudflare_zone.interactiveliterature_org.id]
}
