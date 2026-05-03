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
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.15.1"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.43"
        }
      }
    }
  EOF
}

# Remote state — S3 with DynamoDB locking.
#
# State primitives are scoped per-environment (not per-region) and live in
# ap-northeast-1, the primary region; modules deployed to ap-northeast-2
# access them cross-region with negligible latency.
#
# The bucket name embeds the AWS account ID so a fork using a different
# account naturally gets a globally unique S3 name without manual renaming.
# Both the bucket and the DynamoDB lock table are provisioned by the
# standalone Terraform configuration under bootstrap/.
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket         = "${local.aws_account_id}-${local.project}-${local.environment}-tfstate"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "${local.project}-${local.environment}-tflock"
  }
}

# Pass the merged variable hierarchy to every child module.
inputs = merge(
  local.global_vars.locals,
  local.account_vars.locals,
  local.region_vars.locals,
)
