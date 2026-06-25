include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/secrets"
}

# The cluster's OIDC provider backs the demo-app IRSA trust policy. Passed via
# dependency outputs (not data sources) so plan-all resolves on a fresh stack
# before the cluster exists.
dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/oidc.eks.ap-northeast-1.amazonaws.com/id/MOCK"
    oidc_provider_url = "oidc.eks.ap-northeast-1.amazonaws.com/id/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

# Network primitives for the Secrets Manager interface endpoint.
dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id             = "vpc-mock"
    vpc_cidr_block     = "10.0.0.0/16"
    private_subnet_ids = { "mock-a" = "subnet-mock-a", "mock-c" = "subnet-mock-c" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

inputs = {
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_provider_url = dependency.eks.outputs.oidc_provider_url

  vpc_id             = dependency.network.outputs.vpc_id
  vpc_cidr_block     = dependency.network.outputs.vpc_cidr_block
  private_subnet_ids = dependency.network.outputs.private_subnet_ids
}
