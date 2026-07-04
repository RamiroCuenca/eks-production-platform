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

# The go-demo IRSA policies scope to the data tier's exact secret and key ARNs
# (random suffixes — not constructable), so those must flow in as dependency
# outputs. This serializes {aurora, elasticache} ahead of secrets -> argocd on
# a fresh full-stack apply; accepted, the composed build session runs once.
dependency "aurora" {
  config_path = "../aurora"

  mock_outputs = {
    master_user_secret_arn = "arn:aws:secretsmanager:ap-northeast-1:000000000000:secret:rds!cluster-MOCK-abcdef"
    kms_key_arn            = "arn:aws:kms:ap-northeast-1:000000000000:key/mock-aurora-key"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

dependency "elasticache" {
  config_path = "../elasticache"

  mock_outputs = {
    connection_secret_arn = "arn:aws:secretsmanager:ap-northeast-1:000000000000:secret:eks-platform/dev/redis/connection-abcdef"
    kms_key_arn           = "arn:aws:kms:ap-northeast-1:000000000000:key/mock-redis-key"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

inputs = {
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_provider_url = dependency.eks.outputs.oidc_provider_url

  vpc_id             = dependency.network.outputs.vpc_id
  vpc_cidr_block     = dependency.network.outputs.vpc_cidr_block
  private_subnet_ids = dependency.network.outputs.private_subnet_ids

  aurora_master_secret_arn    = dependency.aurora.outputs.master_user_secret_arn
  aurora_kms_key_arn          = dependency.aurora.outputs.kms_key_arn
  redis_connection_secret_arn = dependency.elasticache.outputs.connection_secret_arn
  redis_kms_key_arn           = dependency.elasticache.outputs.kms_key_arn
}
