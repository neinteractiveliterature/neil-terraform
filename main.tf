terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.48.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.31.0"
    }
    heroku = {
      source  = "heroku/heroku"
      version = "~> 5.1"
    }
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

provider "aws" {
  profile = "neil"
  region  = "us-east-1"
}

provider "heroku" {
}

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
    profile        = "neil"
    region         = "us-east-1"
    bucket         = "neil-terraform-state"
    key            = "terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform_state_locks"
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

resource "aws_dynamodb_table" "terraform_state_locks" {
  name         = "terraform_state_locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
