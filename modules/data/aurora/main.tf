# Cluster parameter group — enforces TLS at the server.
resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.name_prefix}-aurora"
  family      = var.aurora_parameter_group_family
  description = "Aurora PostgreSQL cluster parameters for ${var.name_prefix}"

  # Reject any non-TLS connection at the server so encryption in transit is
  # guaranteed regardless of client configuration — a misconfigured client
  # cannot send credentials or data in cleartext. Mirrors ElastiCache's
  # transit_encryption_enabled for a uniform encrypted-in-transit posture.
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

# Aurora PostgreSQL cluster — provisioned, Multi-AZ via instances in separate AZs.
resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.name_prefix}-aurora"
  engine             = "aurora-postgresql"
  # Pinned; bumped via PR like cluster_version. Verify the exact version is
  # offered in-region before an apply — Aurora trails the open-source minor.
  engine_version = var.aurora_engine_version

  database_name   = var.database_name
  master_username = var.master_username

  # RDS owns the master password end to end: it creates the secret in Secrets
  # Manager, encrypts it with this module's CMK, and rotates it on an
  # AWS-managed schedule. No master_password is set here and there is no custom
  # rotation Lambda. Because rotation is internal to the RDS service, the
  # cluster can sit in intra subnets with no outbound internet path.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.aurora.arn

  # Storage encrypted at rest with the module CMK (not the AWS-managed aws/rds key).
  storage_encrypted = true
  kms_key_id        = aws_kms_key.aurora.arn

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  backup_retention_period      = var.aurora_backup_retention
  preferred_backup_window      = "16:00-16:30"         # UTC, ahead of maintenance
  preferred_maintenance_window = "sun:17:00-sun:17:30" # UTC, after the backup window
  copy_tags_to_snapshot        = true

  # Ship the PostgreSQL log to CloudWatch for the observability story.
  enabled_cloudwatch_logs_exports = ["postgresql"]

  deletion_protection       = var.aurora_deletion_protection
  skip_final_snapshot       = var.aurora_skip_final_snapshot
  final_snapshot_identifier = var.aurora_skip_final_snapshot ? null : "${var.name_prefix}-aurora-final"
}

# Cluster instances. count = aurora_instance_count: the first becomes the writer,
# the rest readers; Aurora spreads them across the subnet group's AZs, so two
# instances give a cross-AZ writer+reader pair (the Multi-AZ failover topology).
resource "aws_rds_cluster_instance" "this" {
  count = var.aurora_instance_count

  identifier         = "${var.name_prefix}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  # Never reachable from the internet (and the intra subnets have no route anyway).
  publicly_accessible = false

  performance_insights_enabled    = var.aurora_performance_insights_enabled
  performance_insights_kms_key_id = var.aurora_performance_insights_enabled ? aws_kms_key.aurora.arn : null
}
