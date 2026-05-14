# System managed node group. The always-on floor that hosts kube-system
# controllers, the Karpenter controller itself, ArgoCD, and observability
# agents. Karpenter has no authority over these nodes — application capacity
# belongs to Karpenter-provisioned NodePools.
#
# Bottlerocket on Graviton (arm64) is the same family as the future Karpenter
# NodePool, so the demo cluster's two compute tiers tell a consistent story.

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "system"
  node_role_arn   = aws_iam_role.system_node.arn
  subnet_ids      = local.subnet_ids

  instance_types = var.system_node_instance_types
  ami_type       = "BOTTLEROCKET_ARM_64"
  capacity_type  = "ON_DEMAND"
  disk_size      = var.system_node_disk_size

  scaling_config {
    desired_size = var.system_node_desired_size
    min_size     = var.system_node_min_size
    max_size     = var.system_node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    "node-tier" = "system"
  }

  # System node group hosts cluster-critical pods; tolerations on those pods
  # match this taint so application workloads can't accidentally schedule
  # here when Karpenter NodePools are at capacity.
  taint {
    key    = "node-tier"
    value  = "system"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name = "${local.cluster_name}-system"
  }

  # AWS auto-creates an EKS access entry of type EC2_LINUX for the node role
  # when the node group is created — no manual access entry needed for the
  # system tier. (Karpenter-launched nodes do need an explicit entry; see
  # access_entries.tf.)
  depends_on = [
    aws_iam_role_policy_attachment.system_node,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
