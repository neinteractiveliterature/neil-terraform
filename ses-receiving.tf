resource "aws_s3_bucket" "intercode_inbox" {
  bucket = "intercode-inbox"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSESPuts",
      "Effect": "Allow",
      "Principal": {
        "Service": "ses.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::intercode-inbox/*",
      "Condition": {
        "StringEquals": {
          "aws:Referer": "${data.aws_caller_identity.current.account_id}"
        }
      }
    }
  ]
}
  EOF
}

resource "aws_s3_bucket_acl" "intercode_inbox" {
  bucket = aws_s3_bucket.intercode_inbox.bucket
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "intercode_inbox" {
  bucket = aws_s3_bucket.intercode_inbox.bucket
  rule {
    id     = "message_expiration"
    status = "Enabled"
    expiration {
      days = 14
    }
  }
}

resource "aws_iam_role" "sns_success_feedback" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "sns.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy" "sns_success_feedback" {
  name = "oneClick_SNSSuccessFeedback_1584129549314"
  role = aws_iam_role.sns_success_feedback.name
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:PutMetricFilter",
            "logs:PutRetentionPolicy",
          ]
          Effect = "Allow"
          Resource = [
            "*",
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role" "sns_failure_feedback" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "sns.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy" "sns_failure_feedback" {
  name = "oneClick_SNSFailureFeedback_1584129549315"
  role = aws_iam_role.sns_failure_feedback.name
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:PutMetricFilter",
            "logs:PutRetentionPolicy",
          ]
          Effect = "Allow"
          Resource = [
            "*",
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_sns_topic" "intercode_inbox_deliveries" {
  name                           = "intercode-inbox-deliveries"
  http_success_feedback_role_arn = aws_iam_role.sns_success_feedback.arn
  http_failure_feedback_role_arn = aws_iam_role.sns_failure_feedback.arn
}

resource "aws_sns_topic_subscription" "intercode_inbox_deliveries_webhook" {
  topic_arn              = aws_sns_topic.intercode_inbox_deliveries.arn
  protocol               = "https"
  endpoint               = "https://www.neilhosting.net/sns_notifications"
  endpoint_auto_confirms = true

  delivery_policy = jsonencode({
    guaranteed = false
    healthyRetryPolicy = {
      backoffFunction    = "linear"
      maxDelayTarget     = 300
      minDelayTarget     = 20
      numMaxDelayRetries = 0
      numMinDelayRetries = 0
      numNoDelayRetries  = 0
      numRetries         = 3
    }
    sicklyRetryPolicy = null
    throttlePolicy    = null
  })
}

resource "aws_ses_receipt_rule_set" "intercode_inbox" {
  rule_set_name = "intercode-inbox"
}

resource "aws_ses_active_receipt_rule_set" "active_rule_set" {
  rule_set_name = aws_ses_receipt_rule_set.intercode_inbox.rule_set_name
}

resource "aws_ses_receipt_rule" "store_and_notify" {
  name          = "store_and_notify"
  rule_set_name = aws_ses_receipt_rule_set.intercode_inbox.rule_set_name
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name = aws_s3_bucket.intercode_inbox.bucket
    position    = 1
    kms_key_arn = "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/ses"
    topic_arn   = aws_sns_topic.intercode_inbox_deliveries.arn
  }
}

resource "aws_ses_configuration_set" "default" {
  name = "default"
}

resource "aws_ses_event_destination" "cloudwatch" {
  name                   = "ses-sends"
  configuration_set_name = aws_ses_configuration_set.default.name
  enabled                = true
  matching_types         = ["bounce", "complaint", "delivery", "reject", "send"]

  cloudwatch_destination {
    default_value  = aws_ses_configuration_set.default.name
    dimension_name = "ses:configuration-set"
    value_source   = "messageTag"
  }
}
