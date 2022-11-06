variable "intercon_furniture_production_db_password" {
  type = string
}

variable "intercon_furniture_intercode_oauth_client_id" {
  type = string
}

variable "intercon_furniture_intercode_oauth_client_secret" {
  type = string
}

variable "intercon_furniture_papertrail_api_token" {
  type = string
}

locals {
  intercon_furniture_domains = toset([
    "furniture.interconlarp.org"
  ])

  intercon_furniture_cors_allowed_origins = [for domain in local.intercon_furniture_domains : "https://${domain}"]
}

# The Heroku app itself
resource "heroku_app" "intercon_furniture" {
  name   = "intercon-furniture"
  region = "us"
  stack  = "heroku-22"
  acm    = true

  organization {
    name = "neinteractiveliterature"
  }

  config_vars = {
    DATABASE_SSL           = "1"
    INTERCODE_CALLBACK_URL = "https://furniture.interconlarp.org/oauth_callback"
    INTERCODE_GRAPHQL_URL  = "https://u.interconlarp.org/graphql"
    INTERCODE_TOKEN_URL    = "https://u.interconlarp.org/oauth/token"
    INTERCODE_URL          = "https://u.interconlarp.org/oauth/authorize"
    INTERCON_BASE_URL      = "https://u.interconlarp.org"
    NODE_ENV               = "production"
    PGSSLMODE              = "noverify"
    SESSION_TYPE           = "postgresql"
    TZ                     = "America/New_York"
  }

  sensitive_config_vars = {
    DATABASE_URL                  = "postgres://intercon_furniture_production:${var.intercon_furniture_production_db_password}@${aws_db_instance.intercode_production.endpoint}/intercon_furniture_production?sslrootcert=rds-combined-ca-bundle-2019.pem"
    INTERCODE_OAUTH_CLIENT_ID     = var.intercon_furniture_intercode_oauth_client_id
    INTERCODE_OAUTH_CLIENT_SECRET = var.intercon_furniture_intercode_oauth_client_secret
    PAPERTRAIL_API_TOKEN          = var.intercon_furniture_papertrail_api_token
  }
}

resource "heroku_domain" "intercon_furniture" {
  for_each = local.intercon_furniture_domains

  app_id   = heroku_app.intercon_furniture.uuid
  hostname = each.value
}
