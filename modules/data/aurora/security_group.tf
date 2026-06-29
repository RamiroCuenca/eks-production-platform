# Aurora security group: ingress only on 5432, only from the EKS cluster.
#
# "Allow only from EKS" is expressed as a security-group REFERENCE rather than a
# CIDR allow — only interfaces carrying the cluster SG are admitted, regardless
# of how the VPC is later re-addressed. Under Cilium ENI IPAM, pod egress leaves
# from Cilium-allocated ENIs; with eni.securityGroups/securityGroupTags unset
# (the current chart config), Cilium copies the SGs from the node's primary ENI,
# which on EKS managed-node-group nodes is this cluster SG — so pod->DB traffic
# is expected to carry it. This is validated at apply (a pod must reach 5432);
# if pod ENIs turn out not to carry the cluster SG, swap to a VPC-CIDR ingress
# rule (var.vpc_cidr_block), the same fallback the Secrets Manager endpoint
# documents for this exact Cilium-ENI reason.
resource "aws_security_group" "aurora" {
  name        = "${var.name_prefix}-aurora"
  description = "PostgreSQL 5432 from the EKS cluster to Aurora"
  vpc_id      = var.vpc_id

  # No egress rule: security groups are stateful, so reply traffic on
  # established connections needs no egress allow, and the database never
  # initiates outbound connections. Leaving egress unmanaged yields the tighter
  # ingress-only posture.

  tags = { Name = "${var.name_prefix}-aurora" }
}

resource "aws_vpc_security_group_ingress_rule" "aurora_postgres" {
  security_group_id            = aws_security_group.aurora.id
  description                  = "PostgreSQL from the EKS cluster security group"
  referenced_security_group_id = var.eks_cluster_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
