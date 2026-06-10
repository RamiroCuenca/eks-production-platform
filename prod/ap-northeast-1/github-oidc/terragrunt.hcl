include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/github-oidc"
}

# CI identity must survive `run-all destroy`: pipelines authenticate on every
# PR, including while cluster infrastructure is torn down. IAM costs nothing
# while standing, so this unit is excluded from destroy runs.
prevent_destroy = true

# IAM is global; the unit lives under the primary region purely to fit the
# env/region state layout — one instantiation per environment, not per region.
# github_org / github_repo flow in from global.hcl via root.hcl's merged
# inputs — only genuinely env-specific values are set here.
inputs = {
  # References the account-singleton OIDC provider created by the dev unit.
  create_oidc_provider = false

  # Prod is plan-on-PR only, and only from runs that passed the GitHub
  # Environment "prod" protection rules (required reviewers + wait timer) —
  # GitHub refuses to stamp environment:prod into the token otherwise.
  # Apply stays operator-local; see the prod runbook.
  github_sub_contexts = ["environment:prod"]
  apply_enabled       = false
}
