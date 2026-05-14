# Variables specific to the prod environment.

locals {
  environment = "prod"

  # EKS Kubernetes version. Kept identical to dev at steady state. During an
  # upgrade soak window, dev bumps first and prod follows after ~1 week once
  # addon compatibility is validated.
  cluster_version = "1.35"

  # CIDRs that may reach the EKS public API endpoint. Tightly allowlisted in
  # prod: the operator IP and the GitHub Actions OIDC IP ranges go here.
  # Placeholder values must be replaced before the first prod apply.
  api_public_access_cidrs = [
    "REPLACE_WITH_OPERATOR_IP/32",
  ]

  common_tags = {
    Environment = "prod"
  }
}
