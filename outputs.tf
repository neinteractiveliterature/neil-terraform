output "intercode_aws_access_key_id" {
  description = "AWS access key ID for the Intercode production IAM user."
  value       = module.intercode_aws_resources.iam_access_key_id
}

output "intercode_aws_secret_access_key" {
  description = "AWS secret access key for the Intercode production IAM user."
  value       = module.intercode_aws_resources.iam_access_key_secret
  sensitive   = true
}
