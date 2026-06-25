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
