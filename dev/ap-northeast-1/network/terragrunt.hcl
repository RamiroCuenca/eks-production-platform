include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/network"
}

# CIDR is per-VPC and lives at the module level. azs, aws_region, and
# name_prefix come from the layered hierarchy via root.hcl's inputs merge.
inputs = {
  cidr_block = "10.0.0.0/16"
}
