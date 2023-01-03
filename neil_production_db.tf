resource "aws_db_parameter_group" "production_pg14" {
  name        = "production-pg14"
  description = "Production parameters (force SSL, tune max_connections)"
  family      = "postgres14"

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
  instance_class        = "db.t4g.micro"
  identifier            = "neil-production"
  engine                = "postgres"
  engine_version        = "14.4"
  username              = "neiladmin"
  password              = var.rds_neiladmin_password
  parameter_group_name  = "production-pg14"
  deletion_protection   = true
  publicly_accessible   = true
  allocated_storage     = 10
  max_allocated_storage = 100
  iops = 3000

  monitoring_role_arn          = aws_iam_role.rds_enhanced_monitoring.arn
  monitoring_interval          = 60
  performance_insights_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true

  tags = {
    "workload-type" = "other"
  }
}
