# Variables specific to the prod environment.

locals {
  environment = "prod"

  # EKS Kubernetes version. Kept identical to dev at steady state. During an
  # upgrade soak window, dev bumps first and prod follows after ~1 week once
  # addon compatibility is validated.
  cluster_version = "1.36"

  # CIDRs that may reach the EKS public API endpoint. Tightly allowlisted in
  # prod: the operator exports OPERATOR_IP_CIDR (e.g. "203.0.113.7/32") at
  # apply time, keeping personal IPs out of a public repository. The default
  # is loopback — syntactically valid for CI plans, and a deny-all posture if
  # a prod apply ever runs without the override: the public endpoint exists
  # but admits no one, while private VPC access stays on.
  api_public_access_cidrs = [
    get_env("OPERATOR_IP_CIDR", "127.0.0.1/32"),
  ]

  # ---- Data tier (Aurora + ElastiCache) sizing ----
  # prod scales the instances up and hardens lifecycle: deletion protection on,
  # a final snapshot taken on destroy, and longer backup/snapshot retention.
  aurora_instance_class      = "db.r6g.large"
  aurora_instance_count      = 3
  aurora_backup_retention    = 14
  aurora_deletion_protection = true
  aurora_skip_final_snapshot = false

  redis_node_type          = "cache.r6g.large"
  redis_num_cache_clusters = 3
  redis_snapshot_retention = 7

  common_tags = {
    Environment = "prod"
  }
}
