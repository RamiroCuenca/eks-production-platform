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

  # Operator IAM principal that receives the cluster-admin access entry on
  # every EKS cluster. Loaded from the shell at apply time. If empty, the EKS
  # module falls back to the IAM identity running `terraform apply` (via
  # `aws_caller_identity`) — convenient for local-only workflows but unsafe
  # once CI also runs apply, so export the env var before that lands.
  operator_iam_arn = get_env("OPERATOR_IAM_ARN", "")

  # GitHub identity trusted by the CI OIDC roles (modules/github-oidc).
  # Account-wide facts — every environment's github-oidc unit consumes the
  # same values via root.hcl's merged inputs.
  github_org  = "RamiroCuenca"
  github_repo = "eks-production-platform"

  # Application source repository. Its main-branch workflow assumes the ECR
  # push role (modules/ecr); kept here with the other GitHub identity facts so
  # trust policies never hardcode repo names.
  github_app_repo = "eks-platform-demo-app"

  common_tags = {
    Project    = "eks-platform"
    Owner      = "RamiroCuenca"
    Repository = "github.com/RamiroCuenca/eks-production-platform"
  }
}
