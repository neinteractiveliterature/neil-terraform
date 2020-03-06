locals {
  intercon_letters = [
    "D", "E", "F", "G", "H", "I", "J", # the Chelmsford years, part I
    "K", # that one year in Waltham
    "L", "M", "N", "O", # the Chelmsford years, part II
    "P", # that one year in Framingham
    "Q", "R", "S", "T", "U" # the Warwick years
  ]
}

resource "aws_s3_bucket" "www_interactiveliterature_org" {
  bucket = "www.interactiveliterature.org"
  acl  = "public-read"
  website_domain = "s3-website-us-east-1.amazonaws.com"
  website_endpoint = "www.interactiveliterature.org.s3-website-us-east-1.amazonaws.com"

  website {
    index_document = "index.html"
    routing_rules = jsonencode(
      concat(
        [
          for letter in local.intercon_letters:
          {
            Condition = {
              HttpErrorCodeReturnedEquals = "404"
              KeyPrefixEquals             = letter
            }
            Redirect  = {
              HostName       = "${lower(letter)}.interconlarp.org"
              Protocol       = "https"
              ReplaceKeyWith = ""
            }
          }
        ],
        [
          {
            Condition = {
              HttpErrorCodeReturnedEquals = "404"
              KeyPrefixEquals             = "Wiki"
            }
            Redirect  = {
              HostName       = "drive.google.com"
              Protocol       = "https"
              ReplaceKeyWith = "drive/folders/1cw0RHoDGbtoy2i0YtU1aD3U-ww3rOcNN?usp=sharing"
            }
          },
        ]
      )
    )
  }
}

resource "aws_iam_group" "interactiveliterature_org_admin" {
  name = "interactiveliterature.org-admin"
}

resource "aws_iam_group_policy_attachment" "interactiveliterature_org_admin_change_password" {
  group = aws_iam_group.interactiveliterature_org_admin.name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

resource "aws_iam_group_policy" "interactiveliterature_org_s3" {
  name = "interactiveliterature.org-s3"
  group = aws_iam_group.interactiveliterature_org_admin.name

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
        "arn:aws:s3:::${aws_s3_bucket.www_interactiveliterature_org.bucket}"
      ]
    },
    {
      "Sid": "objects",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.www_interactiveliterature_org.bucket}/*"
      ]
    }
  ]
}
  EOF
}

resource "aws_iam_group_policy" "interactiveliterature_org_cloudfront" {
  name = "interactiveliterature.org-cloudfront"
  group = aws_iam_group.interactiveliterature_org_admin.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1545167594000",
      "Effect": "Allow",
      "Action": [
        "cloudfront:*"
      ],
      "Resource": [
        "${module.interactiveliterature_org_cloudfront.cloudfront_distribution.arn}"
      ]
    }
  ]
}
  EOF
}

module "interactiveliterature_org_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name = "interactiveliterature.org"
  alternative_names = ["www.interactiveliterature.org"]
  origin_id = "S3-Website-www.interactiveliterature.org.s3-website-us-east-1.amazonaws.com"
  origin_domain_name = aws_s3_bucket.www_interactiveliterature_org.website_endpoint
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}
