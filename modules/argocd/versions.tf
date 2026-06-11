# Provider source attribution for standalone consumption (terraform validate
# in CI runs modules directly, outside Terragrunt). Without this, Terraform
# infers hashicorp/kubectl for the community kubectl provider and fails.
#
# Constraints mirror root.hcl's pins so standalone validation resolves the
# same provider majors the platform runs (helm 3.x changed the provider
# block syntax, so a bare floor would validate against the wrong API). When
# instantiated through Terragrunt, root.hcl generates a versions.tf over
# this file and remains the single source of truth.
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
  }
}
