variable "project" {
  description = "Project name, used as the repository namespace and the CI role prefix. Provided by root.hcl from global.hcl."
  type        = string
}

variable "github_org" {
  description = "GitHub user or organization that owns the application repository. Provided by root.hcl from global.hcl."
  type        = string
}

variable "github_app_repo" {
  description = "Application repository name (without owner) whose main-branch workflow may assume the push role. Provided by root.hcl from global.hcl."
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "ARN of the account-singleton GitHub OIDC identity provider, from the github-oidc unit's outputs. Dependency-passed so this module never has to know whether it was created or data-sourced."
  type        = string
}

variable "permissions_boundary_arn" {
  description = "ARN of the CI permissions boundary from the github-oidc unit. Attached to the push role so every CI identity in the account carries the same ceiling."
  type        = string
}
