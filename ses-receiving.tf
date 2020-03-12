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

resource "aws_sns_topic" "intercode_inbox_deliveries" {
  name = "intercode-inbox-deliveries"
}

resource "aws_sns_topic_subscription" "intercode_inbox_deliveries_webhook" {
  topic_arn = aws_sns_topic.intercode_inbox_deliveries.arn
  protocol = "https"
  endpoint = "https://www.neilhosting.net/sns_notifications"
  endpoint_auto_confirms = true

  delivery_policy = jsonencode({
    guaranteed         = false
    healthyRetryPolicy = {
      backoffFunction    = "linear"
      maxDelayTarget     = 300
      minDelayTarget     = 20
      numMaxDelayRetries = 0
      numMinDelayRetries = 0
      numNoDelayRetries  = 0
      numRetries         = 3
    }
    sicklyRetryPolicy  = null
    throttlePolicy     = null
  })
}

resource "aws_ses_receipt_rule_set" "intercode_inbox" {
  rule_set_name = "intercode-inbox"
}

resource "aws_ses_active_receipt_rule_set" "active_rule_set" {
  rule_set_name = aws_ses_receipt_rule_set.intercode_inbox.rule_set_name
}

resource "aws_ses_receipt_rule" "store_and_notify" {
  name = "store_and_notify"
  rule_set_name = aws_ses_receipt_rule_set.intercode_inbox.rule_set_name
  enabled = true
  scan_enabled = true

  s3_action {
    bucket_name = aws_s3_bucket.intercode_inbox.bucket
    position = 1
    kms_key_arn = "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/ses"
    topic_arn = aws_sns_topic.intercode_inbox_deliveries.arn
  }
}
