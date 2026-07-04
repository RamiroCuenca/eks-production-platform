# Provider source attribution for standalone consumption (terraform validate in
# CI runs modules directly, outside Terragrunt). Constraints mirror root.hcl's
# pins. When instantiated through Terragrunt, root.hcl's generate block
# (if_exists = "overwrite") replaces this file with the platform-wide pins,
# which remain the single source of truth.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.51"
    }
  }
}
