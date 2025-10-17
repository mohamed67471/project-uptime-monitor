
# Parameter group for MySQL tuning
resource "aws_db_parameter_group" "main" {
  name   = "${var.name_prefix}-mysql-params"
  family = "mysql8.0"

  parameter {
    name  = "max_connections"
    value = "100"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = {
    Name = "${var.name_prefix}-params"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = 25
  storage_type          = "gp3"
  storage_encrypted     = true

  # In production would Add custom KMS key
  # kms_key_id = aws_kms_key.rds.arn

  # Database
  db_name  = var.database_name
  username = var.master_username
  password = var.master_password

  # Networking
  multi_az               = var.multi_az
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.main.name

  # Backups
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  copy_tags_to_snapshot   = true

  # Monitoring
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  performance_insights_enabled    = false # disable for demo
  monitoring_interval             = 0     # Basic monitoring (free)


  # Upgrades
  auto_minor_version_upgrade = true
  apply_immediately          = false # Wait for maintenance window

  # Deletion settings for easy teardown
  skip_final_snapshot = true  # Demo only
  deletion_protection = false # demo only

  # PRODUCTION would be:
  # skip_final_snapshot = false
  # final_snapshot_identifier = "${var.name_prefix}-final-${timestamp()}"
  # deletion_protection = true

  tags = {
    Name        = "${var.name_prefix}-mysql"
    Environment = "demo"
    Backup      = "automated"
  }
}

# CloudWatch alarms
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.name_prefix}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Database CPU is too high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}

resource "aws_cloudwatch_metric_alarm" "database_storage" {
  alarm_name          = "${var.name_prefix}-rds-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000"
  alarm_description   = "Database storage is low"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}
