module "intercode_ses_email_receiving" {
  source = "github.com/neinteractiveliterature/intercode//terraform/modules/ses_email_receiving?ref=main&depth=1"

  name                      = "intercode"
  inbox_bucket_name         = "intercode-inbox"
  sns_notification_endpoint = "https://www.neilhosting.net/sns_notifications"
  iam_group_name            = module.intercode_aws_resources.iam_group_name
}

# aws_iam_role.sns_success_feedback / sns_failure_feedback had auto-generated names; the
# module assigns explicit names so these will be recreated with no functional impact.
