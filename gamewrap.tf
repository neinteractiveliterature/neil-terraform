resource "aws_s3_bucket" "gamewrap_interactiveliterature_org" {
  acl    = "public-read"
  bucket = "gamewrap.interactiveliterature.org"
  website_domain   = "s3-website-us-east-1.amazonaws.com"
  website_endpoint = "gamewrap.interactiveliterature.org.s3-website-us-east-1.amazonaws.com"

  website {
    error_document = "error.html"
    index_document = "index.html"
  }
}

resource "aws_iam_group" "gamewrap_s3" {
  name = "gamewrap-s3"
}

resource "aws_iam_group_policy" "gamewrap_s3" {
  name = "gamewrap-s3"
  group = aws_iam_group.gamewrap_s3.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "bucket",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.gamewrap_interactiveliterature_org.bucket}"
      ]
    },
    {
      "Sid": "objects",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.gamewrap_interactiveliterature_org.bucket}/*"
      ]
    }
  ]
}
  EOF
}

resource "aws_iam_group_policy" "gamewrap_cloudfront" {
  name = "gamewrap-cloudfront"
  group = aws_iam_group.gamewrap_s3.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1545167594000",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateInvalidation",
        "cloudfront:GetDistribution"
      ],
      "Resource": [
        "${module.gamewrap_cloudfront.cloudfront_distribution.arn}"
      ]
    }
  ]
}
  EOF
}

resource "aws_iam_user" "gamewrap_s3" {
  name = "gamewrap-s3"
}

resource "aws_iam_user_group_membership" "gamewrap_s3" {
  user = aws_iam_user.gamewrap_s3.name
  groups = [aws_iam_group.gamewrap_s3.name]
}

module "gamewrap_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name = "gamewrap.interactiveliterature.org"
  origin_id = "S3-gamewrap.interactiveliterature.org"
  default_root_object = "index.html"
  validation_method = "NONE"
  origin_domain_name = aws_s3_bucket.gamewrap_interactiveliterature_org.website_endpoint
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}
