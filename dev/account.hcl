# Variables specific to the dev environment.

locals {
  environment = "dev"

  # EKS Kubernetes version. Kept identical to prod at steady state; dev bumps
  # first during upgrade soak windows so addon compatibility can be validated
  # before prod follows. Update both account.hcl files together when bumping.
  cluster_version = "1.35"

  # CIDRs that may reach the EKS public API endpoint. Dev is permissive to
  # accommodate the build-screenshot-destroy lifecycle (kubectl from cafes,
  # hotspots); access is still IAM-authenticated via access entries. Prod
  # tightens this to an operator IP plus the GitHub Actions OIDC ranges.
  api_public_access_cidrs = ["0.0.0.0/0"]

  common_tags = {
    Environment = "dev"
  }
}
