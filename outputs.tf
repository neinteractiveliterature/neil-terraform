output "intercode_aws_access_key_id" {
  description = "AWS access key ID for the Intercode production IAM user."
  value       = module.intercode_aws_resources.iam_access_key_id
}

output "intercode_aws_secret_access_key" {
  description = "AWS secret access key for the Intercode production IAM user."
  value       = module.intercode_aws_resources.iam_access_key_secret
  sensitive   = true
}

output "larp_library_sentry_dsn" {
  description = "Sentry DSN for the Larp Library app (server + frontend). Not secret — safe to set as a plain Fly env var / fly.toml value."
  value       = data.sentry_all_keys.larp_library.keys[0].dsn["public"]
}

output "larp_library_sentry_release_token" {
  description = "Auth token for the Larp Library release rake task to create Sentry releases/deploys. Set by hand via `flyctl secrets set` — see larp_library.tf."
  value       = var.sentry_auth_token
  sensitive   = true
}
