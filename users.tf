resource "aws_iam_user" "dkapell" {
  name = "dkapell"
}

resource "aws_iam_user_group_membership" "dkapell" {
  user = aws_iam_user.dkapell.name
  groups = [
    aws_iam_group.ops_admin.name,
    aws_iam_group.terraform_admin.name
  ]
}
