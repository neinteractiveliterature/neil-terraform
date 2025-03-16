terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    # heroku = {
    #   source  = "heroku/heroku"
    #   version = "~> 5.1"
    # }
    rollbar = {
      source = "rollbar/rollbar"
    }
    github = {
      source = "integrations/github"
    }
  }
  required_version = ">= 1.1"
}

variable "rollbar_token" {
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

# provider "heroku" {
# }

provider "rollbar" {
  api_key = var.rollbar_token
}

variable "cloudflare_email" {
  type = string
}

variable "cloudflare_api_key" {
  type = string
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

variable "fly_gha_api_token" {
  type = string
}

provider "github" {
  owner = "neinteractiveliterature"
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

module "github-oidc" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "~> 1"

  create_oidc_provider = true
  create_oidc_role     = true

  repositories              = ["neinteractiveliterature/neil-terraform"]
  oidc_role_attach_policies = []
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = module.github-oidc.oidc_provider_arn
}

output "github_oidc_role" {
  description = "CICD GitHub role."
  value       = module.github-oidc.oidc_role
}
