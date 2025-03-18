resource "aws_s3_bucket" "gamewrap_interactiveliterature_org" {
  bucket = "gamewrap.interactiveliterature.org"
}

resource "aws_s3_bucket_acl" "gamewrap_interactiveliterature_org" {
  bucket = aws_s3_bucket.gamewrap_interactiveliterature_org.bucket
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "gamewrap_interactiveliterature_org" {
  bucket = aws_s3_bucket.gamewrap_interactiveliterature_org.bucket

  error_document {
    key = "error.html"
  }

  index_document {
    suffix = "index.html"
  }
}

resource "github_repository" "game_wrap" {
  name                 = "game_wrap"
  description          = "The web site for Game Wrap"
  has_downloads        = true
  has_issues           = true
  has_projects         = true
  has_wiki             = true
  vulnerability_alerts = true
}

resource "aws_iam_role" "gamewrap_deploy" {
  name = "gamewrap_deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"

      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" : "repo:${github_repository.game_wrap.full_name}:*"
        }
      }

      Principal = {
        Federated = module.github-oidc.oidc_provider_arn
      }
    }]
  })
}

resource "aws_iam_role_policy" "gamewrap_deploy" {
  role = aws_iam_role.gamewrap_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Action = [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:DeleteObject"
      ]
      Effect = "Allow"

      Resource = "${aws_s3_bucket.gamewrap_interactiveliterature_org.arn}/*"
    }]
  })
}

output "gamewrap_github_oidc_role" {
  description = "Game Wrap deploy role ARN"
  value       = aws_iam_role.gamewrap_deploy.arn
}

resource "cloudflare_dns_record" "interactiveliterature_org_gamewrap_cname" {
  zone_id = cloudflare_zone.interactiveliterature_org.id
  name    = "gamewrap"
  type    = "CNAME"
  proxied = true
  content = aws_s3_bucket_website_configuration.gamewrap_interactiveliterature_org.website_endpoint
  ttl     = 1
}
