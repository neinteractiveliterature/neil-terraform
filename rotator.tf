resource "github_repository" "rotator" {
  name                   = "rotator"
  has_issues             = true
  has_projects           = true
  has_wiki               = false
  delete_branch_on_merge = true
}

resource "github_repository_vulnerability_alerts" "rotator" {
  repository = github_repository.rotator.name
}

module "rotator_sst_github_deployment" {
  source = "github.com/neinteractiveliterature/neil-terraform-modules//sst_github_deployment?ref=main"

  app_name              = "rotator"
  cloudflare_account_id = cloudflare_account.neil.id
  github_repository = {
    name      = github_repository.rotator.name
    full_name = github_repository.rotator.full_name
  }
  oidc_provider_arn         = module.github-oidc.oidc_provider_arn
  writable_cloudflare_zones = [cloudflare_zone.interactiveliterature_org.id]
}

resource "sentry_project" "rotator" {
  organization = sentry_organization.neil.slug

  teams = [sentry_team.neil.slug]
  name  = "Rotator"
  slug  = "rotator"

  platform = "javascript-react-router"
}

resource "github_actions_secret" "rotator_sentry_org" {
  repository  = github_repository.rotator.name
  secret_name = "SENTRY_ORG"
  value       = sentry_organization.neil.slug
}

resource "github_actions_secret" "rotator_sentry_project" {
  repository  = github_repository.rotator.name
  secret_name = "SENTRY_PROJECT"
  value       = sentry_project.rotator.slug
}

resource "github_actions_secret" "rotator_sentry_auth_token" {
  repository  = github_repository.rotator.name
  secret_name = "SENTRY_AUTH_TOKEN"
  value       = var.sentry_auth_token
}

output "rotator_smtp_url" {
  sensitive = true
  value     = module.rotator_sst_github_deployment.smtp_url
}

# The sst_github_deployment module's policy has no SQS, SNS, CloudWatch or IAM role actions, and its Lambda statement
# can't create the event source mapping that connects the Jobs queue to its consumer. This fills the gap for this app
# only. Everything SST creates is named "rotator-production-*", except SNS topics, which the AWS provider names
# "<logical name>-<hash>" without the app prefix (hence "JobsAlerts-*").
resource "aws_iam_role_policy" "rotator_deploy_sst_resources" {
  name = "sst-resources"
  role = reverse(split("/", module.rotator_sst_github_deployment.aws_deploy_oidc_role))[0]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageJobsQueues"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:SetQueueAttributes",
          "sqs:ListQueueTags",
          "sqs:TagQueue",
          "sqs:UntagQueue",
        ]
        Resource = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:rotator-production-*"
      },
      {
        Sid    = "ManageJobsAlertsTopic"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:ListTagsForResource",
          "sns:TagResource",
          "sns:UntagResource",
        ]
        Resource = "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:JobsAlerts-*"
      },
      {
        Sid    = "ManageJobsAlarms"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource",
        ]
        Resource = "arn:aws:cloudwatch:us-east-1:${data.aws_caller_identity.current.account_id}:alarm:rotator-production-*"
      },
      {
        # DescribeAlarms doesn't support resource-level permissions
        Sid      = "ReadAlarms"
        Effect   = "Allow"
        Action   = "cloudwatch:DescribeAlarms"
        Resource = "*"
      },
      {
        # Event source mapping ARNs are UUIDs, so they can't be scoped by name. Creating and changing one is limited to
        # this app's functions instead.
        Sid    = "ManageJobsEventSourceMappings"
        Effect = "Allow"
        Action = [
          "lambda:CreateEventSourceMapping",
          "lambda:UpdateEventSourceMapping",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "lambda:FunctionArn" = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:rotator-production-*"
          }
        }
      },
      {
        # Tagging a mapping on creation is authorized against the mapping itself, not the function
        Sid    = "TagEventSourceMappings"
        Effect = "Allow"
        Action = [
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
        ]
        Resource = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:event-source-mapping:*"
      },
      {
        Sid    = "ReadAndDeleteEventSourceMappings"
        Effect = "Allow"
        Action = [
          "lambda:GetEventSourceMapping",
          "lambda:DeleteEventSourceMapping",
          "lambda:ListEventSourceMappings",
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageApplicationRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:PassRole",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/rotator-production-*"
      },
      {
        # SST attaches only the basic Lambda logging policy to its function roles
        Sid      = "AttachLambdaLoggingPolicy"
        Effect   = "Allow"
        Action   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/rotator-production-*"
        Condition = {
          ArnEquals = {
            "iam:PolicyARN" = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
          }
        }
      },
      {
        Sid    = "ManageApplicationLogGroups"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagResource",
          "logs:UntagResource",
          "logs:ListTagsForResource",
          "logs:ListTagsLogGroup",
        ]
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/rotator-production-*"
      },
      {
        # The provider reads a log group by listing them, which is only authorized against this resource
        Sid      = "FindLogGroups"
        Effect   = "Allow"
        Action   = "logs:DescribeLogGroups"
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group::log-stream:"
      },
      {
        Sid    = "ManageApplicationFunctions"
        Effect = "Allow"
        Action = [
          "lambda:DeleteFunction",
          "lambda:PutFunctionConcurrency",
          "lambda:DeleteFunctionConcurrency",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:CreateFunctionUrlConfig",
          "lambda:GetFunctionUrlConfig",
          "lambda:UpdateFunctionUrlConfig",
          "lambda:DeleteFunctionUrlConfig",
          "lambda:UntagResource",
          "lambda:ListTags",
        ]
        Resource = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:rotator-production-*"
      },
    ]
  })
}
