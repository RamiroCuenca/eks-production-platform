# Provider source attribution for standalone consumption (terraform validate in
# CI runs modules directly, outside Terragrunt). Constraints mirror root.hcl's
# pins so standalone validation resolves the same provider majors the platform
# runs — the helm pin matters specifically because helm 3.x changed the
# provider-block syntax this module's providers.tf relies on (the `kubernetes =
# { ... }` attribute, not the v2 `kubernetes { ... }` block), so the pin must be
# >= 3.0 or a v2 provider would reject the config. When instantiated through
# Terragrunt, root.hcl's generate block
# (if_exists = "overwrite") replaces this file with the platform-wide pins,
# which remain the single source of truth.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.51"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }
  }
}
