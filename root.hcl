# Root Terragrunt configuration.
#
# Every module includes this file via:
#
#   include "root" {
#     path = find_in_parent_folders("root.hcl")
#   }
#
# Configuration is layered from broadest to narrowest scope. Each layer
# can override values from the previous one:
#
#   global.hcl    -> account.hcl    -> region.hcl    -> module-level inputs
#   (org-wide)       (per env)         (per region)     (per module)

locals {
  global_vars  = read_terragrunt_config(find_in_parent_folders("global.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  project        = local.global_vars.locals.project
  aws_account_id = local.global_vars.locals.aws_account_id
  environment    = local.account_vars.locals.environment
  aws_region     = local.region_vars.locals.aws_region

  # Naming prefix for state, locks, and any platform-owned resources.
  name_prefix = "${local.project}-${local.environment}-${local.aws_region}"

  # Tags merged from every layer, applied to all AWS resources via
  # the provider's default_tags block.
  default_tags = merge(
    local.global_vars.locals.common_tags,
    local.account_vars.locals.common_tags,
    local.region_vars.locals.common_tags,
    {
      ManagedBy = "Terragrunt"
    },
  )
}

# AWS provider — pinned region with allowed_account_ids as a guardrail
# against accidentally applying to the wrong AWS account.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region              = "${local.aws_region}"
      allowed_account_ids = ["${local.aws_account_id}"]

      default_tags {
        tags = ${jsonencode(local.default_tags)}
      }
    }
  EOF
}

# Terraform / provider version constraints, generated into every module.
#
# if_exists is plain "overwrite" (not "overwrite_terragrunt") deliberately:
# modules may ship their own versions.tf so `terraform validate` works on
# them standalone in CI (required for non-hashicorp providers like
# gavinbunney/kubectl, whose source can't be inferred). At instantiation the
# platform-wide pins generated here always replace the module's copy —
# overwrite_terragrunt would refuse to touch a file it didn't generate.
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.15.1"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.51"
        }
        tls = {
          source  = "hashicorp/tls"
          version = "~> 4.3"
        }
        # Cluster-touching providers. Declared centrally so every module gets
        # consistent version pinning; only configured (and only authenticated
        # against the cluster) inside modules that actually use them — today,
        # modules/eks/ (Cilium CNI) and modules/argocd/. Declaration alone
        # causes no cluster connection.
        helm = {
          source  = "hashicorp/helm"
          version = "~> 3.2"
        }
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "~> 2.35"
        }
        # gavinbunney/kubectl applies arbitrary manifests without requiring
        # the CRD to exist at plan time — the standard escape hatch for
        # bootstrapping an Application or other CRD-typed resource in the
        # same apply that installs its CRD. Same configured-vs-declared rule
        # as helm/kubernetes: declared centrally, configured only in
        # modules/argocd/providers.tf.
        kubectl = {
          source  = "gavinbunney/kubectl"
          version = "~> 1.19"
        }
      }
    }
  EOF
}

# Remote state — S3 with native S3 lockfile locking.
#
# State primitives are scoped per-environment (not per-region) and live in
# ap-northeast-1, the primary region; modules deployed to ap-northeast-2
# access them cross-region with negligible latency.
#
# `use_lockfile = true` opts into Terraform's S3-native locking
# (Terraform >= 1.10), which uses an S3 conditional-write object as the lock
# instead of a separate DynamoDB table. The state bucket is provisioned by
# the standalone Terraform configuration under bootstrap/.
#
# The bucket name embeds the AWS account ID so a fork using a different
# account naturally gets a globally unique S3 name without manual renaming.
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "${local.aws_account_id}-${local.project}-${local.environment}-tfstate"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Pass the merged variable hierarchy to every child module, plus the
# computed name_prefix so modules don't have to re-stitch project/env/region.
inputs = merge(
  local.global_vars.locals,
  local.account_vars.locals,
  local.region_vars.locals,
  {
    name_prefix = local.name_prefix
  },
)
