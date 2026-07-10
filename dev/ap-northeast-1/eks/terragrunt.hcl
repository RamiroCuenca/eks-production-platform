include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/eks"
}

# Network primitives are owned by the network module in the same region.
dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = { "mock-a" = "subnet-mock-a", "mock-c" = "subnet-mock-c" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

inputs = {
  vpc_id             = dependency.network.outputs.vpc_id
  private_subnet_ids = dependency.network.outputs.private_subnet_ids

  # CI plans and applies run as the ci-dev OIDC role; units that manage
  # in-cluster resources (argocd, addons) need it to reach the K8s API.
  # Cluster-admin because apply manages helm releases, namespaces and secrets.
  additional_access_entries = {
    ci_dev = {
      role_name  = "eks-platform-ci-dev"
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    }
  }
}
