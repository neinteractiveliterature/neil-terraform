resource "aws_iam_group" "rotator_production" {
  name = "rotator-production"
}

resource "aws_iam_group_policy" "rotator_production" {
  name  = "rotator-production"
  group = aws_iam_group.rotator_production.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ses:SendRawEmail",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_user" "rotator_production" {
  name = "rotator-production"
}

resource "aws_iam_user_group_membership" "rotator_production" {
  user   = aws_iam_user.rotator_production.name
  groups = [aws_iam_group.rotator_production.name]
}

resource "aws_iam_access_key" "rotator_production" {
  user = aws_iam_user.rotator_production.name
}

resource "cloudflare_account_token" "rotator_deploy" {
  name = "Rotator deploy key"
  account_id = cloudflare_account.neil.id
  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = module.cloudflare_permissions.permission_groups_by_name["DNS Read"].id },
        { id = module.cloudflare_permissions.permission_groups_by_name["Zone Read"].id },
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.${cloudflare_account.neil.id}" = {
          "com.cloudflare.api.account.zone.*" = "*"
        }
      })
    },
    {
      effect = "allow"
      permission_groups = [
        { id = module.cloudflare_permissions.permission_groups_by_name["DNS Write"].id },
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.zone.${cloudflare_zone.interactiveliterature_org.id}" = "*"
      })
    }
  ]
}

resource "github_repository" "rotator" {
  name                   = "rotator"
  has_issues             = true
  has_projects           = true
  has_wiki               = false
  vulnerability_alerts   = true
  delete_branch_on_merge = true
}

resource "github_actions_secret" "rotator_cloudflare_api_token" {
  repository      = github_repository.rotator.name
  secret_name     = "CLOUDFLARE_API_TOKEN"
  plaintext_value = cloudflare_account_token.rotator_deploy.value
}

resource "github_actions_secret" "rotator_cloudflare_account_id" {
  repository      = github_repository.rotator.name
  secret_name     = "CLOUDFLARE_ACCOUNT_ID"
  plaintext_value = cloudflare_account.neil.id
}

resource "github_actions_secret" "rotator_aws_oidc_role" {
  repository      = github_repository.rotator.name
  secret_name     = "AWS_OIDC_ROLE"
  plaintext_value = aws_iam_role.rotator_deploy.arn
}

resource "aws_iam_role" "rotator_deploy" {
  name = "rotator_deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"

      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" : "repo:${github_repository.rotator.full_name}:*"
        }
      }

      Principal = {
        Federated = module.github-oidc.oidc_provider_arn
      }
    }]
  })
}

resource "aws_iam_role_policy" "rotator_deploy" {
  role = aws_iam_role.rotator_deploy.name

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
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/sst-asset"
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
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/sst/passphrase/*",
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/sst/bootstrap"
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
          "arn:aws:s3:::rotator-production-*",
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
}
