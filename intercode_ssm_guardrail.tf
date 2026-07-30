# Detects manual edits to /intercode_production/* SSM parameters made
# outside of Terraform (e.g. an accidental edit via the AWS console, mixing
# it up with /neil-terraform/*). Every parameter under this path is a
# Terraform-managed aws_ssm_parameter resource, so any write from something
# other than Terraform itself is worth a look.
#
# Rather than trying to positively identify "this came from the console"
# (undocumented and inconsistent across AWS services — some consoles just
# forward the browser's raw User-Agent header), this fires on anything
# whose userAgent ISN'T a known-automation client: Terraform's AWS provider
# (userAgent contains "terraform-provider-aws") or the AWS CLI. That's a
# stable signal that doesn't depend on guessing the console's exact string.
#
# Uses only free-tier building blocks: CloudTrail management events reach
# EventBridge's default bus at no cost (no paid Trail needed), matching a
# rule on the default bus against an AWS-service-sourced event is free, and
# SNS is free at this volume (this should fire rarely, ideally never).
resource "aws_cloudwatch_event_rule" "intercode_production_ssm_manual_edit" {
  name        = "intercode-production-ssm-manual-edit"
  description = "Fires when /intercode_production/* SSM parameters are written or deleted by something other than Terraform"

  event_pattern = jsonencode({
    source      = ["aws.ssm"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ssm.amazonaws.com"]
      eventName   = ["PutParameter", "DeleteParameter"]
      requestParameters = {
        name = [{ prefix = "/intercode_production/" }]
      }
      userAgent = [
        { "anything-but" = { wildcard = ["*terraform-provider-aws*", "aws-cli/*"] } }
      ]
    }
  })
}

resource "aws_sns_topic" "intercode_production_ssm_manual_edit" {
  name = "intercode-production-ssm-manual-edit"
}

resource "aws_sns_topic_policy" "intercode_production_ssm_manual_edit" {
  arn = aws_sns_topic.intercode_production_ssm_manual_edit.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgePublish"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.intercode_production_ssm_manual_edit.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.intercode_production_ssm_manual_edit.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "intercode_production_ssm_manual_edit" {
  for_each = local.intercode_production_alarm_email_destinations

  topic_arn = aws_sns_topic.intercode_production_ssm_manual_edit.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_event_target" "intercode_production_ssm_manual_edit" {
  rule = aws_cloudwatch_event_rule.intercode_production_ssm_manual_edit.name
  arn  = aws_sns_topic.intercode_production_ssm_manual_edit.arn
}
