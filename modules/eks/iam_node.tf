# Node IAM roles. Two parallel roles, identical policy set:
#
#   - aws_iam_role.system_node — attached to the EKS managed node group that
#     hosts kube-system controllers, Karpenter, ArgoCD, and observability.
#   - aws_iam_role.karpenter_node + aws_iam_instance_profile.karpenter_node —
#     used by Karpenter-launched EC2 instances. The instance profile is
#     referenced by Karpenter's EC2NodeClass in the gitops repo.
#
# Both roles get the same baseline:
#
#   - AmazonEKSWorkerNodePolicy            — basic worker node permissions
#   - AmazonEKS_CNI_Policy                 — VPC CNI ENI management
#   - AmazonEC2ContainerRegistryReadOnly   — pull from ECR
#   - AmazonSSMManagedInstanceCore         — Bottlerocket admin via SSM
#                                            (host has no shell)

locals {
  node_managed_policies = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  node_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ---------- System NG node role ----------

resource "aws_iam_role" "system_node" {
  name               = "${local.cluster_name}-system-node"
  assume_role_policy = local.node_assume_role_policy
}

resource "aws_iam_role_policy_attachment" "system_node" {
  for_each = toset(local.node_managed_policies)

  role       = aws_iam_role.system_node.name
  policy_arn = each.value
}

# ---------- Karpenter node role ----------

resource "aws_iam_role" "karpenter_node" {
  name               = "${local.cluster_name}-karpenter-node"
  assume_role_policy = local.node_assume_role_policy
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = toset(local.node_managed_policies)

  role       = aws_iam_role.karpenter_node.name
  policy_arn = each.value
}

# Instance profile referenced by Karpenter's EC2NodeClass (`role:` field).
# Karpenter passes this profile to RunInstances, so launched nodes assume
# the karpenter_node role at boot.
resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${local.cluster_name}-karpenter-node"
  role = aws_iam_role.karpenter_node.name
}
