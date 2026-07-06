output "primary_endpoint" {
  description = "Primary (write) endpoint address — cluster-mode-disabled groups expose a single primary endpoint."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint" {
  description = "Reader endpoint address — load-balances reads across replicas; the app's read path targets this."
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "port" {
  description = "Redis port."
  value       = aws_elasticache_replication_group.this.port
}

output "connection_secret_arn" {
  description = "ARN of the connection/AUTH secret. The go-demo runtime IRSA policy scopes its read grant to this ARN."
  value       = aws_secretsmanager_secret.connection.arn
}

output "connection_secret_name" {
  description = "Name of the connection secret — referenced as the SecretProviderClass objectName in the gitops chart."
  value       = aws_secretsmanager_secret.connection.name
}

output "kms_key_arn" {
  description = "ARN of the customer-managed key encrypting Redis at-rest data and its secret. The app IRSA policy scopes its kms:Decrypt grant to this key."
  value       = aws_kms_key.redis.arn
}

output "security_group_id" {
  description = "Redis security group ID."
  value       = aws_security_group.redis.id
}
