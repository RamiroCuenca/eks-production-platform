locals {
  connection_secret_name = "eks-platform/${var.environment}/aurora/connection"
}

# Connection details for the consuming app: endpoints, port, database name.
# CREDENTIALS are deliberately NOT here — they live in the RDS-managed master
# secret (manage_master_user_password). Endpoints are not sensitive, but keeping
# them in Secrets Manager lets the app retrieve everything through the same
# IRSA/ASCP mount path the secrets module already provides, rather than mixing a secret
# mount with injected env-vars. Encrypted with the module CMK.
resource "aws_secretsmanager_secret" "connection" {
  name        = local.connection_secret_name
  description = "Aurora connection details (endpoints, port, dbname). Credentials live in the RDS-managed master secret."
  kms_key_id  = aws_kms_key.aurora.arn

  # recovery_window_in_days = 0 keeps teardown symmetric with apply (matches the
  # state bucket force_destroy and the standalone demo secret): without it a
  # re-apply inside the recovery window fails with "scheduled for deletion".
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "connection" {
  secret_id = aws_secretsmanager_secret.connection.id
  secret_string = jsonencode({
    host        = aws_rds_cluster.this.endpoint
    reader_host = aws_rds_cluster.this.reader_endpoint
    port        = aws_rds_cluster.this.port
    dbname      = var.database_name
  })
}
