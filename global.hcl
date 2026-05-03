# Organization-wide variables, inherited by every environment and region.
#
# A single AWS account hosts both dev and prod in this project. A real
# production deployment would split environments across separate accounts
# under AWS Organizations; the Terragrunt layout here keeps that split a
# configuration-only change.

locals {
  project = "eks-platform"

  # Loaded from the shell at apply time so the ID stays out of git history.
  aws_account_id = get_env("AWS_ACCOUNT_ID", "")

  common_tags = {
    Project    = "eks-platform"
    Owner      = "RamiroCuenca"
    Repository = "github.com/RamiroCuenca/eks-production-platform"
  }
}
