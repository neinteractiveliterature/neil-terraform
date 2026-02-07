resource "github_repository" "game_wrap" {
  name                 = "game_wrap"
  description          = "The web site for Game Wrap"
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

    Statement = [
      {
        "Sid" : "ManageBootstrapStateBucket",
        "Effect" : "Allow",
        "Action" : [
          "s3:CreateBucket",
          "s3:PutBucketVersioning",
          "s3:PutBucketNotification",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ],
        "Resource" : [
          "arn:aws:s3:::sst-state-*"
        ]
      },
      {
        "Sid" : "ManageBootstrapAssetBucket",
        "Effect" : "Allow",
        "Action" : [
          "s3:CreateBucket",
          "s3:PutBucketVersioning",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ],
        "Resource" : [
          "arn:aws:s3:::sst-asset-*"
        ]
      },
      {
        "Sid" : "ManageBootstrapECRRepo",
        "Effect" : "Allow",
        "Action" : [
          "ecr:CreateRepository",
          "ecr:DescribeRepositories"
        ],
        "Resource" : [
          "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/sst-asset"
        ]
      },
      {
        "Sid" : "ManageBootstrapSSMParameter",
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter"
        ],
        "Resource" : [
          "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/sst/passphrase/*",
          "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/sst/bootstrap"
        ]
      },
      {
        "Sid" : "ManageApplicationProductionBucket",
        "Effect" : "Allow",
        "Action" : [
          "s3:CreateBucket",
          "s3:PutBucketVersioning",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ],
        "Resource" : [
          "arn:aws:s3:::game-wrap-production-*",
          "arn:aws:s3:::sst-asset-*"
        ]
      },
      {
        "Sid" : "ManageLambdaFunctions",
        "Effect" : "Allow",
        "Action" : [
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode",
          "lambda:ListVersionsByFunction",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:InvokeFunction",
          "lambda:UpdateFunctionConfiguration"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Sid" : "ManageCloudfrontDistributions",
        "Effect" : "Allow",
        "Action" : [
          "cloudfront:CreateInvalidation"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
  # })
}

output "gamewrap_github_oidc_role" {
  description = "Game Wrap deploy role ARN"
  value       = aws_iam_role.gamewrap_deploy.arn
}
