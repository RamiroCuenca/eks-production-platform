# ElastiCache Redis — replication group, cluster mode DISABLED.
#
# One node group (a primary + replicas) rather than a sharded, cluster-mode-on
# topology: the demo never needs horizontal sharding, and cluster mode would
# force a cluster-aware client in the Go app and the redis-cluster variant of
# the KEDA scaler. This still demonstrates everything that matters — replication,
# Multi-AZ automatic failover, encryption at rest and in transit, and AUTH.
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "Redis replication group for ${var.name_prefix}"

  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  port                 = 6379
  parameter_group_name = var.redis_parameter_group_name

  # Cluster mode off: a single node group of (primary + replicas). Multi-AZ with
  # automatic failover promotes a replica if the primary's AZ fails; both
  # require >= 2 nodes (enforced by the dev default of 2).
  num_cache_clusters         = var.redis_num_cache_clusters
  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  # Encryption at rest with the module CMK, and in transit (TLS) with an AUTH
  # token. transit_encryption_enabled is the prerequisite for auth_token.
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.redis.arn
  transit_encryption_enabled = true
  auth_token                 = random_password.auth.result
  auth_token_update_strategy = "ROTATE"

  snapshot_retention_limit = var.redis_snapshot_retention
  snapshot_window          = "17:00-18:00"         # UTC, before maintenance
  maintenance_window       = "sun:18:00-sun:19:00" # UTC, after the snapshot window

  apply_immediately = true
}
