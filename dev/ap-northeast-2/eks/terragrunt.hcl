include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/eks"
}

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
}
