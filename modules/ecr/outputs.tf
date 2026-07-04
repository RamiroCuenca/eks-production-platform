output "repository_url" {
  description = "Full registry URL (account.dkr.ecr.region.amazonaws.com/name). Account-specific, so it reaches the gitops chart only through the ArgoCD cluster-Secret annotation bridge."
  value       = aws_ecr_repository.demo_app.repository_url
}

output "repository_arn" {
  description = "Repository ARN the app CI role's push policy is scoped to."
  value       = aws_ecr_repository.demo_app.arn
}

output "repository_name" {
  description = "Repository name, for console lookups and the app CI workflow's tag composition."
  value       = aws_ecr_repository.demo_app.name
}

output "app_ci_role_arn" {
  description = "Role ARN the app repository's workflow passes to aws-actions/configure-aws-credentials."
  value       = aws_iam_role.app_ci.arn
}
