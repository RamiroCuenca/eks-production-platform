include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/argocd"
}

# EKS provides every per-cluster fact the ArgoCD cluster Secret needs to
# carry forward to the gitops-repo ApplicationSets.
dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name                      = "eks-platform-dev-ap-northeast-1"
    karpenter_controller_role_arn     = "arn:aws:iam::000000000000:role/mock-karpenter-controller"
    karpenter_node_role_name          = "mock-karpenter-node"
    karpenter_interruption_queue_name = "mock-karpenter-interruption"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

inputs = {
  cluster_name                      = dependency.eks.outputs.cluster_name
  karpenter_controller_role_arn     = dependency.eks.outputs.karpenter_controller_role_arn
  karpenter_node_role_name          = dependency.eks.outputs.karpenter_node_role_name
  karpenter_interruption_queue_name = dependency.eks.outputs.karpenter_interruption_queue_name

  gitops_repo_url = "https://github.com/RamiroCuenca/eks-platform-gitops.git"

  # Dev posture: single-replica everything. Prod will set ha_enabled = true.
  ha_enabled = false
}
