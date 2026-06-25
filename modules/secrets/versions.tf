# Provider source attribution for standalone consumption (terraform validate in
# CI runs modules directly, outside Terragrunt). Constraints mirror root.hcl's
# pins. When instantiated through Terragrunt, root.hcl's generate block
# (if_exists = "overwrite") replaces this file with the platform-wide pins,
# which remain the single source of truth.
#
# This module is AWS-only plus the random provider it uses to generate the
# demonstration credential value. It never connects to the cluster, so no
# kubernetes/helm provider configuration exists here and the plan needs no
# cluster CA — unlike modules/eks and modules/argocd.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.51"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
