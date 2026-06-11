# Variables specific to the prod environment.

locals {
  environment = "prod"

  # EKS Kubernetes version. Kept identical to dev at steady state. During an
  # upgrade soak window, dev bumps first and prod follows after ~1 week once
  # addon compatibility is validated.
  cluster_version = "1.35"

  # CIDRs that may reach the EKS public API endpoint. Tightly allowlisted in
  # prod: the operator exports OPERATOR_IP_CIDR (e.g. "203.0.113.7/32") at
  # apply time, keeping personal IPs out of a public repository. The default
  # is loopback — syntactically valid for CI plans, and a deny-all posture if
  # a prod apply ever runs without the override: the public endpoint exists
  # but admits no one, while private VPC access stays on.
  api_public_access_cidrs = [
    get_env("OPERATOR_IP_CIDR", "127.0.0.1/32"),
  ]

  common_tags = {
    Environment = "prod"
  }
}
