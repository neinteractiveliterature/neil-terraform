provider "aws" {
  profile = "neil"
  region = "us-east-1"
}

terraform {
  backend "s3" {
    profile = "neil"
    region = "us-east-1"
    bucket = "neil-terraform-state"
    key    = "terraform.tfstate"
    encrypt = true
    kms_key_id = "arn:aws:kms:us-east-1:689053117832:key/9c5f29f3-3d5d-4d9d-a16f-d081ecb3b152"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "neil-terraform-state" {
  description = "Encryption key for Terraform state"
}

resource "aws_s3_bucket" "neil-terraform-state" {
  bucket = "neil-terraform-state"
  region = "us-east-1"
  versioning {
    enabled = true
  }
}
