# Variables specific to the dev environment.

locals {
  environment = "dev"

  # EKS Kubernetes version. Kept identical to prod at steady state; dev bumps
  # first during upgrade soak windows so addon compatibility can be validated
  # before prod follows. Prod follows ~1 week after dev validates clean.
  cluster_version = "1.36"

  # CIDRs that may reach the EKS public API endpoint. Dev is permissive to
  # accommodate the build-screenshot-destroy lifecycle (kubectl from cafes,
  # hotspots); access is still IAM-authenticated via access entries. Prod
  # tightens this to an operator IP plus the GitHub Actions OIDC ranges.
  api_public_access_cidrs = ["0.0.0.0/0"]

  # ---- Data tier (Aurora + ElastiCache) sizing ----
  # dev runs the minimum that demonstrates Multi-AZ: a cross-AZ writer+reader
  # pair and a primary+replica cache. Small Graviton, short backups, and no
  # deletion protection so `terragrunt destroy` is clean under the
  # build-screenshot-destroy lifecycle. Engine versions are pinned in the
  # module defaults (bumped via PR like cluster_version).
  aurora_instance_class      = "db.t4g.medium"
  aurora_instance_count      = 2
  aurora_backup_retention    = 1
  aurora_deletion_protection = false
  aurora_skip_final_snapshot = true

  redis_node_type          = "cache.t4g.micro"
  redis_num_cache_clusters = 2
  redis_snapshot_retention = 0

  common_tags = {
    Environment = "dev"
  }
}
