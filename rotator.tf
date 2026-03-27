resource "github_repository" "rotator" {
  name                   = "rotator"
  has_issues             = true
  has_projects           = true
  has_wiki               = false
  vulnerability_alerts   = true
  delete_branch_on_merge = true
}

module "rotator_sst_github_deployment" {
  source = "github.com/neinteractiveliterature/neil-terraform-modules//sst_github_deployment?ref=v1.0.0"

  app_name = "rotator"
  cloudflare_account_id = cloudflare_account.neil.id
  github_repository = github_repository.rotator
  oidc_provider_arn = module.github-oidc.oidc_provider_arn
  writable_cloudflare_zones = [cloudflare_zone.interactiveliterature_org]
}

resource "sentry_project" "rotator" {
  organization = sentry_organization.neil.slug

  teams = [sentry_team.neil.slug]
  name = "Rotator"
  slug = "rotator"

  platform = "javascript-react-router"
}

resource "github_actions_secret" "rotator_sentry_org" {
  repository      = github_repository.rotator.name
  secret_name     = "SENTRY_ORG"
  plaintext_value = sentry_organization.neil.slug
}

resource "github_actions_secret" "rotator_sentry_project" {
  repository      = github_repository.rotator.name
  secret_name     = "SENTRY_PROJECT"
  plaintext_value = sentry_project.rotator.slug
}

resource "github_actions_secret" "rotator_sentry_auth_token" {
  repository      = github_repository.rotator.name
  secret_name     = "SENTRY_AUTH_TOKEN"
  plaintext_value = var.sentry_auth_token
}

output "rotator_smtp_url" {
  sensitive = true
  value = module.rotator_sst_github_deployment.smtp_url
}
