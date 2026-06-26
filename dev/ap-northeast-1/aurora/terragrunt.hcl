include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/data/aurora"
}

# Network primitives: the cluster's instances live in the intra subnets (no
# internet route) and its security group is created in the VPC. Passed via
# dependency outputs (not data sources) so plan-all resolves on a fresh stack
# before the network exists.
dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id           = "vpc-mock"
    vpc_cidr_block   = "10.0.0.0/16"
    intra_subnet_ids = { "mock-a" = "subnet-mock-a", "mock-c" = "subnet-mock-c" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

# The EKS cluster security group sources the Aurora ingress allow (5432).
dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_security_group_id = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

inputs = {
  vpc_id           = dependency.network.outputs.vpc_id
  vpc_cidr_block   = dependency.network.outputs.vpc_cidr_block
  intra_subnet_ids = dependency.network.outputs.intra_subnet_ids

  eks_cluster_security_group_id = dependency.eks.outputs.cluster_security_group_id
}
