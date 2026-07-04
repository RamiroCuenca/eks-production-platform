include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/ecr"
}

# The registry must survive `run --all destroy`: the gitops repo pins an image
# tag, and a vanished repository would leave every rebuild dangling until CI
# re-pushed. Storage for one small image is under a cent per month. The final
# project teardown lifts this guard; force_delete inside the module handles
# the non-empty delete.
prevent_destroy = true

# ECR is regional, but this repository is an account-level artifact store —
# one instantiation under the primary region, same layout rationale as the
# github-oidc unit. dev and prod (same account) pull the same repository.
dependency "github_oidc" {
  config_path = "../github-oidc"

  mock_outputs = {
    github_oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
    permissions_boundary_arn = "arn:aws:iam::000000000000:policy/mock-ci-boundary"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

inputs = {
  github_oidc_provider_arn = dependency.github_oidc.outputs.github_oidc_provider_arn
  permissions_boundary_arn = dependency.github_oidc.outputs.permissions_boundary_arn
}
