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

# Mirrors aws_iam_group_policy.this in the intercode_aws_resources module
# (the static IAM user's permissions) so this role can fully replace that
# user once CHAMBER_AWS_ROLE_ARN is wired up and the static key is retired.
resource "aws_iam_role_policy" "intercode_chamber_app" {
  name = "app-access"
  role = aws_iam_role.intercode_chamber.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:RestoreObject",
        ]
        Resource = "${module.intercode_aws_resources.s3_bucket_arn}/*"
      },
      {
        Sid      = "S3BucketAccess"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListAllMyBuckets", "s3:ListBucket"]
        Resource = "arn:aws:s3:::*"
      },
      {
        Sid    = "SqsAccess"
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:ChangeMessageVisibilityBatch",
          "sqs:DeleteMessage",
          "sqs:DeleteMessageBatch",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:SendMessage",
          "sqs:SendMessageBatch",
          "sqs:ListQueues",
        ]
        Resource = "arn:aws:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:intercode_production_*"
      },
      {
        Sid      = "SesAccess"
        Effect   = "Allow"
        Action   = ["ses:SendRawEmail", "ses:SendBounce"]
        Resource = "*"
      },
      {
        Sid    = "CloudwatchSchedulerProvisioning"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
        ]
        Resource = [
          "arn:aws:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:intercode_production_cloudwatch_scheduler",
          "arn:aws:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:intercode_production_cloudwatch_scheduler-failures",
        ]
      },
      {
        Sid      = "CloudwatchSchedulerAccess"
        Effect   = "Allow"
        Action   = ["events:PutRule", "events:PutTargets"]
        Resource = "*"
      },
    ]
  })
}

output "intercode_chamber_role_arn" {
  description = "ARN of the IAM role Fly machines assume via OIDC to read SSM parameters for chamber."
  value       = aws_iam_role.intercode_chamber.arn
}

# Keeps CHAMBER_AWS_ROLE_ARN in sync with the role's ARN so entrypoint.sh's
# existing OIDC code path (see intercode#11852) can pick it up — staged only
# (not applied immediately) since null_resource.intercode_fly_redeploy is what
# actually triggers a deploy, and it depends on this so the secret is staged
# before that deploy runs.
resource "null_resource" "intercode_chamber_role_arn_secret" {
  triggers = {
    role_arn = aws_iam_role.intercode_chamber.arn
  }

  provisioner "local-exec" {
    command = "flyctl secrets set --app intercode --stage CHAMBER_AWS_ROLE_ARN=${aws_iam_role.intercode_chamber.arn}"
  }
}
