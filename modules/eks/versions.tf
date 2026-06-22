# Provider source attribution for standalone consumption (terraform validate in
# CI runs modules directly, outside Terragrunt). Constraints mirror root.hcl's
# pins so standalone validation resolves the same provider majors the platform
# runs — the helm pin matters specifically because helm 3.x changed the
# provider-block syntax this module's providers.tf relies on (the nested
# `kubernetes { ... }` block), so a bare floor would validate against the wrong
# API. When instantiated through Terragrunt, root.hcl's generate block
# (if_exists = "overwrite") replaces this file with the platform-wide pins,
# which remain the single source of truth.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.43"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}
