# Redis security group: ingress only on 6379, only from the EKS cluster.
#
# Same design and Cilium ENI-IPAM rationale as the Aurora SG (see
# modules/data/aurora/security_group.tf): a security-group reference expresses
# "reachable from the cluster, nothing else" more tightly than a CIDR allow.
# Validated at apply (a pod must reach 6379); documented fallback is a VPC-CIDR
# ingress rule (var.vpc_cidr_block) if Cilium pod ENIs do not carry the cluster SG.
resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-redis"
  description = "Redis 6379 from the EKS cluster to ElastiCache"
  vpc_id      = var.vpc_id

  # No egress rule: stateful replies need none and the cache never initiates
  # outbound connections — the tighter ingress-only posture.

  tags = { Name = "${var.name_prefix}-redis" }
}

resource "aws_vpc_security_group_ingress_rule" "redis" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Redis from the EKS cluster security group"
  referenced_security_group_id = var.eks_cluster_security_group_id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}
