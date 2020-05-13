variable "intercode_production_db_password" {
  type = string
}

# The Heroku app itself
resource "heroku_app" "intercode" {
  name = "intercode"
  region = "us"
  stack = "container"

  organization {
    name = "neinteractiveliterature"
  }

  # we do our own cert management shenanigans using scheduled jobs
  acm = false

  config_vars = {
    INTERCODE_CERTS_NO_WILDCARD_DOMAINS = "5pi-con.natbudin.com"
    INTERCODE_HOST = "neilhosting.net"
    RACK_ENV = "production"
    RAILS_ENV = "production"
    RAILS_LOG_TO_STDOUT = "enabled"
    RAILS_MAX_THREADS = "4"
    RAILS_SERVE_STATIC_FILES = "enabled"
    UPLOADS_HOST = "https://uploads.neilhosting.net"
    WEB_CONCURRENCY = "1"
    YARN_PRODUCTION = "true"
  }

  sensitive_config_vars = {
    AWS_ACCESS_KEY_ID = aws_iam_access_key.intercode2_production.id
    AWS_REGION = data.aws_region.current.name
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.intercode2_production.secret
    AWS_S3_BUCKET = aws_s3_bucket.intercode2_production.bucket
    DATABASE_URL = "postgres://intercode_production:${var.intercode_production_db_password}@${aws_db_instance.intercode_production.endpoint}/intercode_production?sslrootcert=rds-combined-ca-bundle-2019.pem"
  }
}

resource "aws_db_parameter_group" "production_pg12" {
  name = "production-pg12"
  description = "Production parameters (force SSL, tune max_connections)"
  family = "postgres12"

  parameter {
    apply_method = "immediate"
    name         = "rds.force_ssl"
    value        = "1"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "max_connections"
    value        = "100"
  }
}

# The production Postgres database
resource "aws_db_instance" "intercode_production" {
  instance_class = "db.t2.micro"
  engine         = "postgres"
  engine_version = "12.2"
  username       = "neiladmin"
  parameter_group_name = "production-pg12"
  deletion_protection = true
  publicly_accessible = true

  monitoring_interval = 60
  performance_insights_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot = true

  tags = {
    "workload-type" = "other"
  }
}

# SQS queues used by Shoryuken for background processing
resource "aws_sqs_queue" "intercode_production_dead_letter" {
  name = "intercode_production_dead_letter"
}

resource "aws_sqs_queue" "intercode_production_default" {
  name = "intercode_production_default"
  redrive_policy                    = jsonencode(
    {
      deadLetterTargetArn = aws_sqs_queue.intercode_production_dead_letter.arn
      maxReceiveCount     = 3
    }
  )
}

resource "aws_sqs_queue" "intercode_production_mailers" {
  name = "intercode_production_mailers"
  redrive_policy                    = jsonencode(
    {
      deadLetterTargetArn = aws_sqs_queue.intercode_production_dead_letter.arn
      maxReceiveCount     = 3
    }
  )
}

resource "aws_sqs_queue" "intercode_production_ahoy" {
  name = "intercode_production_ahoy"
  redrive_policy                    = jsonencode(
    {
      deadLetterTargetArn = aws_sqs_queue.intercode_production_dead_letter.arn
      maxReceiveCount     = 3
    }
  )
}

# uploads.neilhosting.net, aka intercode2_production, is the Cloudfront-served S3 bucket we use
# for uploaded CMS content and product images
resource "aws_s3_bucket" "intercode2_production" {
  acl    = "private"
  bucket = "intercode2-production"
}

resource "aws_route53_record" "uploads_neilhosting_net" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "uploads.neilhosting.net"
  type = "CNAME"
  ttl = 300
  records = ["${module.uploads_neilhosting_net_cloudfront.cloudfront_distribution.domain_name}."]
}

module "uploads_neilhosting_net_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name = "uploads.neilhosting.net"
  origin_id = "S3-intercode2-production"
  origin_domain_name = aws_s3_bucket.intercode2_production.bucket_domain_name
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  route53_zone = aws_route53_zone.neilhosting_net
}

# assets.neilhosting.net is a CloudFront distribution that caches whatever neilhosting.net is
# serving.  Intercode points asset URLs at that domain so that they can be served over CDN
resource "aws_route53_record" "assets_neilhosting_net" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "assets.neilhosting.net"
  type = "CNAME"
  ttl = 300
  records = ["${module.assets_neilhosting_net_cloudfront.cloudfront_distribution.domain_name}."]
}

module "assets_neilhosting_net_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name = "assets.neilhosting.net"
  origin_id = "intercode"
  origin_domain_name = "www.neilhosting.net"
  origin_protocol_policy = "https-only"
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
  route53_zone = aws_route53_zone.neilhosting_net
}

# IAM policy so that Intercode can access the stuff it needs to access in AWS
resource "aws_iam_group" "intercode2_production" {
  name = "intercode2-production"
}

resource "aws_iam_group_policy" "intercode2_production" {
  name = "intercode2-production"
  group = aws_iam_group.intercode2_production.name

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BackupFolderAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObjectVersion",
        "s3:DeleteObjectVersion",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:RestoreObject"
      ],
      "Resource": [
        "${aws_s3_bucket.intercode2_production.arn}/*",
        "${aws_s3_bucket.intercode_inbox.arn}/*"
      ]
    },
    {
      "Sid": "BucketLevelAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListAllMyBuckets",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::*"
      ]
    },
    {
      "Sid": "ShoryukenAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:ChangeMessageVisibility",
        "sqs:ChangeMessageVisibilityBatch",
        "sqs:DeleteMessage",
        "sqs:DeleteMessageBatch",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ReceiveMessage",
        "sqs:SendMessage",
        "sqs:SendMessageBatch",
        "sqs:ListQueues"
      ],
      "Resource": "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:intercode_production_*"
    },
    {
      "Sid": "AcmeShListAccess",
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListHostedZonesByName",
        "route53:GetHostedZoneCount"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AcmeShDomainAccess",
      "Effect": "Allow",
      "Action": [
        "route53:GetHostedZone",
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/${aws_route53_zone.neilhosting_net.zone_id}"
    },
    {
      "Sid": "SesAccess",
      "Effect":"Allow",
      "Action":[
        "ses:SendRawEmail",
        "ses:SendBounce"
      ],
      "Resource":"*"
    },
    {
      "Sid": "SnsAccess",
      "Effect":"Allow",
      "Action":[
        "sns:ConfirmSubscription"
      ],
      "Resource": "${aws_sns_topic.intercode_inbox_deliveries.arn}"
    },
    {
      "Sid": "KmsAccess",
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/2570e363-9e0e-4a1a-b4de-41c2460786df"
    }
  ]
}
  EOF

  # TODO: I can't figure out a good way to avoid hardcoding the key ID in KmsAccess, maybe figure
  # it out later
}

resource "aws_iam_user" "intercode2_production" {
  name = "intercode2-production"
}

resource "aws_iam_user_group_membership" "intercode2_production" {
  user = aws_iam_user.intercode2_production.name
  groups = [aws_iam_group.intercode2_production.name]
}

resource "aws_iam_access_key" "intercode2_production" {
  user = aws_iam_user.intercode2_production.name
}
