output "ci_role_arn" {
  description = "Role ARN the GitHub Actions workflow passes to aws-actions/configure-aws-credentials."
  value       = aws_iam_role.ci.arn
}

output "ci_role_name" {
  description = "Role name, for console lookups and policy refinements."
  value       = aws_iam_role.ci.name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider (created here or referenced, depending on create_oidc_provider)."
  value       = local.github_oidc_provider_arn
}

output "permissions_boundary_arn" {
  description = "ARN of the boundary policy capping the CI role."
  value       = aws_iam_policy.permissions_boundary.arn
}
