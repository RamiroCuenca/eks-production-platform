output "cluster_endpoint" {
  description = "Writer (primary) endpoint — DNS that always points at the current writer instance."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint — load-balances across reader instances; the app's read path targets this."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "port" {
  description = "PostgreSQL port."
  value       = aws_rds_cluster.this.port
}

output "database_name" {
  description = "Initial database name."
  value       = var.database_name
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed master credential secret (username/password, auto-rotated). The go-demo db-init IRSA policy scopes its read grant to this ARN."
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}

output "connection_secret_arn" {
  description = "ARN of the Terraform-written connection secret (endpoints/port/dbname). The go-demo runtime IRSA policy scopes to this ARN."
  value       = aws_secretsmanager_secret.connection.arn
}

output "connection_secret_name" {
  description = "Name of the connection secret — referenced as the SecretProviderClass objectName in the gitops chart."
  value       = aws_secretsmanager_secret.connection.name
}

output "kms_key_arn" {
  description = "ARN of the customer-managed key encrypting Aurora storage and its secrets. The app IRSA policy scopes its kms:Decrypt grant to this key."
  value       = aws_kms_key.aurora.arn
}

output "security_group_id" {
  description = "Aurora security group ID."
  value       = aws_security_group.aurora.id
}
