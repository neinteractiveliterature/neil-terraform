data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# Groups

resource "aws_identitystore_group" "ops_admin" {
  identity_store_id = local.identity_store_id
  display_name      = "ops-admin"
  description       = "Full administrator access to the AWS account"
}

resource "aws_identitystore_group" "terraform_admin" {
  identity_store_id = local.identity_store_id
  display_name      = "terraform-admin"
  description       = "Access to the OpenTofu state bucket and lock table"
}

# Users
# Email addresses come from SSM (local.secrets) rather than being hardcoded, so
# personal contact info doesn't land in this public repo's history.

resource "aws_identitystore_user" "dkapell" {
  identity_store_id = local.identity_store_id
  display_name      = "Dave Kapell"
  user_name         = "dkapell"

  name {
    given_name  = "Dave"
    family_name = "Kapell"
  }

  emails {
    value   = local.secrets["identity_center_dkapell_email"]
    primary = true
  }
}

resource "aws_identitystore_user" "nbudin" {
  identity_store_id = local.identity_store_id
  display_name      = "Nat Budin"
  user_name         = "nbudin"

  name {
    given_name  = "Nat"
    family_name = "Budin"
  }

  emails {
    value   = local.secrets["identity_center_nbudin_email"]
    primary = true
  }
}

# Group memberships (mirrors the aws_iam_user_group_membership assignments in users.tf)

resource "aws_identitystore_group_membership" "dkapell_ops_admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.ops_admin.group_id
  member_id         = aws_identitystore_user.dkapell.user_id
}

resource "aws_identitystore_group_membership" "dkapell_terraform_admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.terraform_admin.group_id
  member_id         = aws_identitystore_user.dkapell.user_id
}

resource "aws_identitystore_group_membership" "nbudin_ops_admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.ops_admin.group_id
  member_id         = aws_identitystore_user.nbudin.user_id
}

resource "aws_identitystore_group_membership" "nbudin_terraform_admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.terraform_admin.group_id
  member_id         = aws_identitystore_user.nbudin.user_id
}

# Permission sets (mirror the IAM group policies in admin-groups.tf)

resource "aws_ssoadmin_permission_set" "ops_admin" {
  name         = "ops-admin"
  instance_arn = local.sso_instance_arn
  description  = "Full administrator access to the AWS account"
}

resource "aws_ssoadmin_managed_policy_attachment" "ops_admin_administrator_access" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.ops_admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_permission_set" "terraform_admin" {
  name         = "terraform-admin"
  instance_arn = local.sso_instance_arn
  description  = "Access to the OpenTofu state bucket and lock table"
}

resource "aws_ssoadmin_permission_set_inline_policy" "terraform_admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.terraform_admin.arn

  inline_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ],
        "Resource": "arn:aws:s3:::neil-terraform-state"
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Resource": "arn:aws:s3:::neil-terraform-state/*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        "Resource": "arn:aws:dynamodb:*:*:table/terraform_state_locks"
      }
    ]
  }
  EOF
}

# Account assignments

resource "aws_ssoadmin_account_assignment" "ops_admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.ops_admin.arn

  principal_id   = aws_identitystore_group.ops_admin.group_id
  principal_type = "GROUP"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "terraform_admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.terraform_admin.arn

  principal_id   = aws_identitystore_group.terraform_admin.group_id
  principal_type = "GROUP"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
}
