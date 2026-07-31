# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

OpenTofu (not HashiCorp Terraform CLI) configuration that manages all infrastructure for New England
Interactive Literature (NEIL): AWS, Cloudflare DNS/zones, Fly.io app secrets, GitHub repos, Sentry,
Rollbar, and Stripe webhooks. It's a single flat root module — no environments, no workspaces, no
per-app subdirectories. Every `.tf` file at the root is part of one big plan.

## Commands

This is infra-as-code, not an application — there is no build/test suite. The relevant commands:

- `tofu init -backend-config=backend.hcl` — required once per checkout; `backend.hcl` is gitignored
  and holds the local `profile` (AWS SSO profile name) used to reach the state bucket. Not needed in
  CI, which authenticates via OIDC instead.
- `tofu plan` / `tofu apply` — `secrets.auto.tfvars` (gitignored) supplies the `aws_profile` variable
  automatically; you need an active `aws sso login --profile neil` session first.
- `tofu validate`, `tofu fmt` — also run in CI (`.github/workflows/terraform.yaml`) on every push:
  `tofu fmt -check`, `tofu init -input=false`, `tofu validate`. Run these yourself before considering
  a change done; CI does not run `plan`/`apply`.
- No CI step ever applies — applies are run locally by a human.

## Secrets

Nearly every credential (API keys, tokens, IAM secrets exposed to Terraform) lives in SSM Parameter
Store under `/neil-terraform/<name>`, read once in `main.tf` via
`data.aws_ssm_parameters_by_path.neil_terraform_secrets` and exposed everywhere else as
`local.secrets["<name>"]`. When a resource needs a new secret, add the SSM parameter (out of band,
via AWS CLI/console) and reference it through `local.secrets`, rather than a new `.tfvars` variable.
`aws_profile` is the one exception — it authenticates the provider itself, so it stays a plain
tfvar in `secrets.auto.tfvars`.

Fly.io apps (e.g. `intercode`) don't get static AWS credentials for reading their own SSM secrets at
runtime; they federate via the Fly OIDC provider (`fly_oidc.tf`) into a scoped IAM role
(`intercode-chamber`) that only grants `ssm:GetParameter*` under that app's own SSM path. Wiring the
running app to pick this role up (e.g. `CHAMBER_AWS_ROLE_ARN`) is a deliberate manual, undocumented
step — see the comment at the bottom of `fly_oidc.tf` for why a `null_resource`/`local-exec` was
rejected as a way to automate it (can't detect drift, silently desyncs instead of failing loud).

## Shared modules

Most nontrivial resources come from two external module sources, both pinned to `ref=main` (a
mutable ref, not a version tag — check the actual upstream commit if behavior seems to have changed
underneath you):

- `github.com/neinteractiveliterature/neil-terraform-modules` — generic building blocks:
  `cloudflare_permissions`, `cloudflare_apex_redirect`, `cloudfront_with_acm`,
  `forwardemail_receiving_domain`, `ses_sending_domain`, `sst_github_deployment`.
- `github.com/neinteractiveliterature/intercode//terraform/modules/*` — Intercode-app-specific:
  `intercode_aws_resources`, `sentry`, `ses_email_receiving`, `forwardemail_receiving`. This lives in
  the separate `intercode` app repo, not here.

## Per-domain files

Files named after a domain (`concentral.net.tf`, `extraconlarp.org.tf`, `interconlarp.org.tf`,
`neilhosting.net.tf`, `occultopus.org.tf`, `intercon.cc.tf`, `interactiveliterature.org.tf`,
`larp_library.tf`) follow the same shape: a `cloudflare_zone`, its zone settings (SSL mode,
always-use-https, security headers), an apex-redirect module instance, either an SES or ForwardEmail
receiving-domain module for inbound mail, and a pile of `cloudflare_dns_record` resources (often
`for_each`-driven from a `locals` map of subdomain → target). When adding a new domain, copy the
pattern from the most recently touched file of this kind rather than inventing a new shape.

App/service files (`intercode.tf`, `listmonk.tf`, `rotator.tf`, `gamewrap.tf`,
`intercon_furniture.tf`) hold the non-DNS resources for one specific service — IAM users/groups,
GitHub repo config, Sentry/Rollbar projects, module wiring.

## Database

One shared RDS Postgres instance, `aws_db_instance.neil_production` (`neil_production.tf`), hosts
every app's database as a separate role/schema (e.g. `intercode_production`). Roles are managed
directly against the live instance with the `cyrilgdn/postgresql` provider (not through the AWS
provider). Migration to RDS IAM authentication is in progress on a per-role basis: granting a role
`rds_iam` immediately invalidates its stored password (not a gradual coexistence), so only do this
once the consuming app is confirmed to generate its own IAM auth tokens.

- **A `tofu apply` that reports success does not mean an RDS setting took effect** — some changes
  (e.g. IAM auth) land in `PendingModifiedValues` rather than applying immediately. Verify against
  live AWS state (`aws rds describe-db-instances`) and force with `apply-immediately` if needed.
- `aws_rds_reserved_instance.offering_id` is read fresh (and differently) from AWS's catalog on every
  plan; it's set to `ignore_changes` deliberately — don't remove that, and don't treat drift here as
  real.

## `moved` blocks

Many files carry `moved { from = ... to = ... }` blocks from incremental refactors of inline
resources into shared modules, usually with a comment noting when the move is NOT a clean rename
(i.e. it forces a resource recreation because a name changed) and what manual follow-up that implies
(e.g. re-confirming SNS subscriptions, updating app credentials). When doing a similar refactor,
follow this pattern — add the `moved` block and call out ForceNew implications in a comment — rather
than deleting and recreating resources silently.

## Scope discipline (infra-specific)

- Implement the smallest change that resolves the issue. Do NOT expand IAM policies, replace existing
  auth mechanisms, or refactor adjacent code unless explicitly asked.
- When an approach requires a `null_resource`/`local-exec`, or otherwise lacks drift detection, stop
  and ask before proceeding — see the Fly OIDC comment above for a case where this was rejected.
- For RDS changes, verify the setting actually applied (check `PendingModifiedValues`) rather than
  trusting a successful `apply`.
