output "demo_app_secrets_role_arn" {
  description = "IRSA role ARN the demo ServiceAccount must annotate with eks.amazonaws.com/role-arn. Propagated to the gitops repo via the ArgoCD cluster Secret."
  value       = aws_iam_role.demo_app_secrets.arn
}

output "demo_secret_name" {
  description = "Secrets Manager secret name the demo SecretProviderClass references as its objectName. Env-scoped; propagated via the ArgoCD cluster Secret."
  value       = aws_secretsmanager_secret.demo.name
}

output "demo_secret_arn" {
  description = "Full ARN of the demo secret (includes the random suffix). The IRSA policy scopes to this exact value."
  value       = aws_secretsmanager_secret.demo.arn
}

output "app_secrets_kms_key_arn" {
  description = "ARN of the customer-managed key encrypting application secrets."
  value       = aws_kms_key.app_secrets.arn
}

output "go_demo_secrets_role_arn" {
  description = "Runtime IRSA role ARN the go-demo ServiceAccount is annotated with. Propagated via the ArgoCD cluster Secret."
  value       = aws_iam_role.go_demo.arn
}

output "go_demo_db_init_role_arn" {
  description = "Db-init IRSA role ARN the one-shot Job's ServiceAccount is annotated with. Propagated via the ArgoCD cluster Secret."
  value       = aws_iam_role.go_demo_db_init.arn
}

output "go_demo_db_secret_name" {
  description = "Name of the generated app-user DB credential secret — the go-demo SecretProviderClass objectName. Propagated via the ArgoCD cluster Secret."
  value       = aws_secretsmanager_secret.go_demo_db.name
}

output "go_demo_db_secret_arn" {
  description = "Full ARN of the app-user DB credential secret (includes the random suffix). Both go-demo IRSA policies scope to this exact value."
  value       = aws_secretsmanager_secret.go_demo_db.arn
}

output "go_demo_db_username" {
  description = "The least-privilege DB username inside the credential secret. Propagated via the ArgoCD cluster Secret so the chart's DB_USER env and the secret's contents share one source."
  value       = var.go_demo_db_username
}
