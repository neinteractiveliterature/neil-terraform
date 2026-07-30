locals {
  intercon_furniture_domains = toset([
    "furniture.interconlarp.org"
  ])

  intercon_furniture_cors_allowed_origins = [for domain in local.intercon_furniture_domains : "https://${domain}"]
}
