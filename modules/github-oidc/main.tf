# GitHub Actions OIDC federation: one CI role per environment, assumed via
# AssumeRoleWithWebIdentity — no static AWS keys live in GitHub.
#
# The identity provider for token.actions.githubusercontent.com is an
# account-level singleton. With dev and prod sharing one account, exactly one
# instantiation of this module creates it (create_oidc_provider = true) and
# the others reference it by URL. In a multi-account split each account would
# flip the flag to true and nothing else changes.

data "aws_partition" "current" {}

locals {
  role_name     = "${var.project}-ci-${var.environment}"
  boundary_name = "${local.role_name}-boundary"

  # Must stay in sync with the remote_state bucket formula in root.hcl.
  state_bucket = "${var.aws_account_id}-${var.project}-${var.environment}-tfstate"

  oidc_hostname = "token.actions.githubusercontent.com"

  github_oidc_provider_arn = (
    var.create_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : data.aws_iam_openid_connect_provider.github[0].arn
  )

  # repo:<org>/<repo>:<context> — the shape GitHub stamps into the token's
  # sub claim. Multiple entries in a StringLike list are OR'd by IAM.
  sub_claims = [
    for context in var.github_sub_contexts :
    "repo:${var.github_org}/${var.github_repo}:${context}"
  ]
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.oidc_hostname}"
  client_id_list = ["sts.amazonaws.com"]

  # AWS validates GitHub's issuer against its own trusted-CA library since
  # 2023 and ignores thumbprints for this URL; the well-known values are kept
  # so the resource is explicit about what was historically trusted.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://${local.oidc_hostname}"
}

# The trust policy is the actual security control here: aud pins the token
# audience to STS, and sub pins which repo and which workflow context may
# assume the role. The prod tier trusts only environment:prod, which GitHub
# itself refuses to stamp into a token unless the run passed the Environment's
# protection rules (required reviewers, wait timer) — a malicious PR editing
# the workflow file cannot mint that claim.
resource "aws_iam_role" "ci" {
  name                 = local.role_name
  description          = "GitHub Actions CI role for the ${var.environment} environment, assumed via OIDC federation."
  permissions_boundary = aws_iam_policy.permissions_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_hostname}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${local.oidc_hostname}:sub" = local.sub_claims
        }
      }
    }]
  })
}
