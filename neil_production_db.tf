resource "aws_db_parameter_group" "production_pg15" {
  name        = "production-pg15"
  description = "Production parameters (force SSL, tune max_connections)"
  family      = "postgres15"

  parameter {
    apply_method = "pending-reboot"
    name         = "rds.force_ssl"
    value        = "1"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "max_connections"
    value        = "100"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "rds.logical_replication"
    value        = "1"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "max_wal_senders"
    value        = "35"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "max_logical_replication_workers"
    value        = "35"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "max_worker_processes"
    value        = "40"
  }
}

resource "aws_db_parameter_group" "production_pg16" {
  name        = "production-pg16"
  description = "Production parameters (force SSL, tune max_connections, enable logical replication)"
  family      = "postgres16"

  parameter {
    apply_method = "pending-reboot"
    name         = "rds.force_ssl"
    value        = "1"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "max_connections"
    value        = "100"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "rds.logical_replication"
    value        = "1"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "max_wal_senders"
    value        = "35"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "max_logical_replication_workers"
    value        = "35"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "max_worker_processes"
    value        = "40"
  }
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "iam_role_rds_enhanced_monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]
}

# The production Postgres database
resource "aws_db_instance" "neil_production" {
  instance_class        = "db.t4g.small"
  identifier            = "neil-production"
  engine                = "postgres"
  engine_version        = "16.3"
  username              = "neiladmin"
  password              = var.rds_neiladmin_password
  parameter_group_name  = "production-pg16"
  deletion_protection   = true
  publicly_accessible   = true
  allocated_storage     = 10
  max_allocated_storage = 100
  iops                  = 3000

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_role_arn             = aws_iam_role.rds_enhanced_monitoring.arn
  monitoring_interval             = 60
  performance_insights_enabled    = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true

  tags = {
    "workload-type" = "other"
  }
}

resource "aws_cloudwatch_metric_alarm" "neil_production_low_disk_space" {
  alarm_name          = "NEIL Production DB low disk space"
  alarm_description   = "Free disk space on NEIL production database has fallen below 5GB."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  threshold           = 5 * 1024 * 1024 * 1024

  alarm_actions = [aws_sns_topic.intercode_production_alarms.arn]

  namespace   = "AWS/RDS"
  metric_name = "FreeStorageSpace"
  period      = 300
  statistic   = "Average"
}

resource "aws_cloudwatch_metric_alarm" "neil_production_high_read_latency" {
  alarm_name          = "NEIL Production DB high read latency"
  alarm_description   = "90th percentile read latency on the NEIL production database is greater than 100ms."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 2
  threshold           = 0.1

  alarm_actions = [aws_sns_topic.intercode_production_alarms.arn]

  metric_query {
    id          = "q1"
    return_data = true

    metric {
      namespace   = "AWS/RDS"
      metric_name = "ReadLatency"
      period      = 10
      stat        = "p90"
    }
  }
}
