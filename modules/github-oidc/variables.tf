variable "project" {
  description = "Project name, used as the prefix for the CI role and its policies. Provided by root.hcl from global.hcl."
  type        = string
}

variable "environment" {
  description = "Environment this CI role serves (dev, prod). Provided by root.hcl from account.hcl."
  type        = string
}

variable "aws_account_id" {
  description = "Account hosting the roles. Used in policy ARNs and to derive the state bucket name. Provided by root.hcl from global.hcl."
  type        = string
}

variable "github_org" {
  description = "GitHub user or organization that owns the repository trusted by the role."
  type        = string
}

variable "github_repo" {
  description = "Repository name (without owner) trusted by the role."
  type        = string
}

variable "github_sub_contexts" {
  description = <<-EOT
    Workflow contexts allowed to assume the role, appended to
    "repo:<org>/<repo>:" in the trust policy's sub condition. Examples:
    "pull_request", "ref:refs/heads/main", "environment:prod". Multiple
    entries are OR'd.
  EOT
  type        = list(string)
}

variable "create_oidc_provider" {
  description = "Whether this instantiation creates the account-singleton GitHub OIDC identity provider. Exactly one unit per account sets this to true; the rest reference the provider by URL."
  type        = bool
  default     = false
}

variable "apply_enabled" {
  description = "true grants the service-scoped apply allowlist (dev: plan-on-PR + apply-on-merge); false grants ReadOnlyAccess plus state-lockfile writes (prod: plan-on-PR only, apply stays operator-local)."
  type        = bool
  default     = false
}

variable "allowed_regions" {
  description = "Regions the permissions boundary confines the role to. Everything else is denied regardless of attached policies."
  type        = list(string)
  default     = ["ap-northeast-1", "ap-northeast-2"]
}
