locals {
  connection_secret_name = "eks-platform/${var.environment}/redis/connection"
}

# Generated AUTH token. ElastiCache requires 16-128 printable characters and
# disallows '/', '"', '@', and spaces — override_special is restricted to a safe
# set (none of the forbidden characters appear). The value lives only in
# Terraform state (the private, encrypted state bucket) and the connection
# secret, never in Git. ROTATE strategy lets a future apply rotate it without
# downtime.
resource "random_password" "auth" {
  length           = 64
  override_special = "!&#$^<>-_=+"
}

# Connection details for the consuming app: endpoints, port, and the AUTH token.
# Unlike Aurora (whose credentials are RDS-managed), ElastiCache has no managed
# secret, so the AUTH token is generated here and stored alongside the
# endpoints. Encrypted with the module CMK; recovery_window_in_days = 0 for
# symmetric teardown (matches Aurora and the Phase 5 demo secret).
resource "aws_secretsmanager_secret" "connection" {
  name        = local.connection_secret_name
  description = "Redis connection details (endpoints, port) + AUTH token for the demo app."
  kms_key_id  = aws_kms_key.redis.arn

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "connection" {
  secret_id = aws_secretsmanager_secret.connection.id
  secret_string = jsonencode({
    primary_endpoint = aws_elasticache_replication_group.this.primary_endpoint_address
    reader_endpoint  = aws_elasticache_replication_group.this.reader_endpoint_address
    port             = aws_elasticache_replication_group.this.port
    auth_token       = random_password.auth.result
  })
}
