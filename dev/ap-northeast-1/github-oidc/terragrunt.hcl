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
  # Account-singleton GitHub OIDC provider is created here; the prod unit
  # references it by URL (and must therefore be applied after this one).
  create_oidc_provider = true

  # PRs plan, merges to main apply.
  github_sub_contexts = ["pull_request", "ref:refs/heads/main"]
  apply_enabled       = true
}
