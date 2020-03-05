resource "aws_s3_bucket" "intercode2_production" {
  acl    = "private"
  bucket = "intercode2-production"
}

resource "aws_db_instance" "intercode_production" {
  instance_class = "db.t2.micro"
  engine         = "postgres"
  engine_version = "10.9"
  username       = "neiladmin"
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
        "arn:aws:s3:::${aws_s3_bucket.intercode2_production.bucket}/*"
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
    }
  ]
}
  EOF
}
