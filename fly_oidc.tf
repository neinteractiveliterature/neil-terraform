locals {
  fly_org_slug = "new-england-interactive-literature"
}

data "tls_certificate" "fly_oidc" {
  url = "https://oidc.fly.io/${local.fly_org_slug}"
}

resource "aws_iam_openid_connect_provider" "fly" {
  url             = "https://oidc.fly.io/${local.fly_org_slug}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.fly_oidc.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "intercode_chamber" {
  name = "intercode-chamber"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.fly.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "oidc.fly.io/${local.fly_org_slug}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "oidc.fly.io/${local.fly_org_slug}:sub" = "${local.fly_org_slug}:intercode:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "intercode_chamber_ssm" {
  name = "ssm-read"
  role = aws_iam_role.intercode_chamber.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
      ]
      Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/intercode_production/*"
    }]
  })
}

output "intercode_chamber_role_arn" {
  description = "ARN of the IAM role Fly machines assume via OIDC to read SSM parameters for chamber."
  value       = aws_iam_role.intercode_chamber.arn
}
