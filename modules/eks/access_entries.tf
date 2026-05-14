# EKS access entries — IAM-to-cluster bindings declared as first-class AWS
# resources rather than as edits to the aws-auth ConfigMap. The cluster runs
# in authentication_mode = API (set in main.tf), so this is the only
# mechanism granting K8s identity to IAM principals.

# ---------- Operator access entry ----------

resource "aws_eks_access_entry" "operator" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = local.operator_iam_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "operator_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.operator.principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# ---------- Karpenter node access entry ----------

# Karpenter-launched nodes are not part of an EKS managed node group, so EKS
# won't auto-create an access entry for the karpenter_node role. Without
# this entry, kubelet running on Karpenter-launched instances cannot
# register with the API server.
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"
}

# ---------- Additional access entries (e.g. GitHub Actions OIDC role) ----------

resource "aws_eks_access_entry" "additional" {
  for_each = var.additional_access_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "additional" {
  for_each = var.additional_access_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.additional[each.key].principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type = "cluster"
  }
}
