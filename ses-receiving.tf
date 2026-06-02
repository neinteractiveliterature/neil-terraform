module "intercode_ses_email_receiving" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/ses_email_receiving?ref=cloudfront-og-shell"

  name                      = "intercode"
  inbox_bucket_name         = "intercode-inbox"
  sns_notification_endpoint = "https://www.neilhosting.net/sns_notifications"
  iam_group_name            = module.intercode_aws_resources.iam_group_name
}

moved {
  from = aws_s3_bucket.intercode_inbox
  to   = module.intercode_ses_email_receiving.aws_s3_bucket.inbox
}

moved {
  from = aws_s3_bucket_acl.intercode_inbox
  to   = module.intercode_ses_email_receiving.aws_s3_bucket_acl.inbox
}

moved {
  from = aws_s3_bucket_policy.intercode_inbox
  to   = module.intercode_ses_email_receiving.aws_s3_bucket_policy.inbox
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.intercode_inbox
  to   = module.intercode_ses_email_receiving.aws_s3_bucket_lifecycle_configuration.inbox
}

moved {
  from = aws_sns_topic.intercode_inbox_deliveries
  to   = module.intercode_ses_email_receiving.aws_sns_topic.inbox_deliveries
}

moved {
  from = aws_sns_topic_subscription.intercode_inbox_deliveries_webhook
  to   = module.intercode_ses_email_receiving.aws_sns_topic_subscription.inbox_deliveries_webhook
}

moved {
  from = aws_ses_receipt_rule_set.intercode_inbox
  to   = module.intercode_ses_email_receiving.aws_ses_receipt_rule_set.inbox
}

moved {
  from = aws_ses_active_receipt_rule_set.active_rule_set
  to   = module.intercode_ses_email_receiving.aws_ses_active_receipt_rule_set.inbox
}

moved {
  from = aws_ses_receipt_rule.store_and_notify
  to   = module.intercode_ses_email_receiving.aws_ses_receipt_rule.store_and_notify
}

# aws_ses_configuration_set.default: name changes "default" → "intercode-default" (ForceNew
# → will be destroyed and recreated; update DEFAULT_CONFIGURATION_SET in the app accordingly)
moved {
  from = aws_ses_configuration_set.default
  to   = module.intercode_ses_email_receiving.aws_ses_configuration_set.default
}

moved {
  from = aws_ses_event_destination.cloudwatch
  to   = module.intercode_ses_email_receiving.aws_ses_event_destination.cloudwatch
}

# aws_iam_role.sns_success_feedback / sns_failure_feedback had auto-generated names; the
# module assigns explicit names so these will be recreated with no functional impact.
