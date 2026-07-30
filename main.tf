terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.19.0"
    }
    rollbar = {
      source = "rollbar/rollbar"
    }
    github = {
      source = "integrations/github"
    }
    sentry = {
      source  = "jianyuan/sentry"
      version = "0.15.0-beta3"
    }
    null = {
      source = "hashicorp/null"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.27.0"
    }
    stripe = {
      source  = "stripe/stripe"
      version = "0.2.3"
    }
  }
  required_version = ">= 1.6"
}

variable "rollbar_token" {
  type      = string
  sensitive = true
}

variable "sentry_auth_token" {
  type      = string
  sensitive = true
}

variable "aws_profile" {
  type = string
}

provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile
}

# Explicit us-east-1 alias required by modules that deploy Lambda@Edge
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile
}

provider "postgresql" {
  host                = aws_db_instance.neil_production.address
  port                = aws_db_instance.neil_production.port
  username            = "neiladmin"
  sslmode             = "require"
  superuser           = false
  aws_rds_iam_auth    = true
  aws_rds_iam_profile = var.aws_profile
  aws_rds_iam_region  = "us-east-1"
}

provider "stripe" {
  api_key = var.intercode_stripe_secret_key
}

# provider "heroku" {
# }

provider "rollbar" {
  api_key = var.rollbar_token
}

variable "cloudflare_email" {
  type = string
}

variable "cloudflare_api_key" {
  type      = string
  sensitive = true
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

variable "fly_gha_api_token" {
  type      = string
  sensitive = true
}

variable "forwardemail_api_key" {
  type      = string
  sensitive = true
}

provider "github" {
  owner = "neinteractiveliterature"
}

provider "sentry" {
  token = var.sentry_auth_token
}

resource "sentry_organization" "neil" {
  name = "NEIL"
  slug = "neinteractiveliterature"

  agree_terms = true
}

resource "sentry_team" "neil" {
  organization = sentry_organization.neil.slug

  name = "new-england-interactive-literature-team"
  slug = "new-england-interactive-literature-team"
}

terraform {
  backend "s3" {
    region       = "us-east-1"
    bucket       = "neil-terraform-state"
    key          = "terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Replaces secrets.auto.tfvars: each secret currently passed in as a plain
# tfvar lives here instead, as a SecureString under /neil-terraform/<name>.
# aws_profile itself can't move here — it's what authenticates this very
# provider, so it has to stay a plain variable.
data "aws_ssm_parameters_by_path" "neil_terraform_secrets" {
  path      = "/neil-terraform"
  recursive = true
}

locals {
  secrets = zipmap(
    [for name in data.aws_ssm_parameters_by_path.neil_terraform_secrets.names : trimprefix(name, "/neil-terraform/")],
    data.aws_ssm_parameters_by_path.neil_terraform_secrets.values
  )
}

resource "aws_s3_bucket" "neil-terraform-state" {
  bucket = "neil-terraform-state"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "neil-terraform-state" {
  bucket = aws_s3_bucket.neil-terraform-state.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "neil-terraform-state" {
  bucket = aws_s3_bucket.neil-terraform-state.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_policy" "neil-terraform-state-read" {
  name = "neil-terraform-state-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${aws_s3_bucket.neil-terraform-state.bucket}/*"
      },
    ]
  })
}

resource "cloudflare_account" "neil" {
  name = "New England Interactive Literature"

  lifecycle {
    # Provider bug: Update function doesn't pass account_id to the API (v5.19.1)
    ignore_changes = all
  }
}

module "cloudflare_permissions" {
  source = "github.com/neinteractiveliterature/neil-terraform-modules//cloudflare_permissions?ref=main"
}

module "github-oidc" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "~> 1"

  create_oidc_provider = true
  create_oidc_role     = true

  repositories              = ["neinteractiveliterature/neil-terraform"]
  oidc_role_attach_policies = [aws_iam_policy.neil-terraform-state-read.arn]
}
