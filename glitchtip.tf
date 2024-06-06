resource "aws_s3_bucket" "neil_glitchtip" {
  bucket = "neil-glitchtip"
}

resource "aws_iam_user" "neil_glitchtip" {
  name = "neil_glitchtip"
}

resource "aws_iam_user_policy" "neil_glitchtip" {
  user   = aws_iam_user.neil_glitchtip.name
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "s3:GetObjectVersion",
            "s3:DeleteObjectVersion",
            "s3:DeleteObject",
            "s3:GetObject",
            "s3:PutObject",
            "s3:RestoreObject"
          ],
          "Resource": [
            "${aws_s3_bucket.neil_glitchtip.arn}/*"
          ]
        },
        {
            "Effect": "Allow",
            "Action": "ses:SendRawEmail",
            "Resource": "*"
        }
    ]
  }
  EOF
}

resource "aws_iam_access_key" "neil_glitchtip" {
  user = aws_iam_user.neil_glitchtip.name
}
