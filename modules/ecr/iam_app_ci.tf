# CI identity for the application repository — colocated with the registry so
# the module reads as "the artifact store and the only identity that may write
# to it". The infra pipeline's roles stay in modules/github-oidc; this role
# reuses that module's account-singleton OIDC provider and permissions
# boundary via dependency outputs.
#
# Trust is deliberately narrower than the infra ci-dev role: only tokens
# minted for the app repo's main branch may assume it. Pull requests build
# and scan the image without any AWS identity at all — a malicious PR cannot
# even authenticate, never mind push.

locals {
  # Matches the eks-platform-ci-* pattern, so the boundary's self-protection
  # denies (detachment, boundary-policy mutation) cover this role unchanged.
  app_ci_role_name = "${var.project}-ci-app"

  oidc_hostname = "token.actions.githubusercontent.com"
}

resource "aws_iam_role" "app_ci" {
  name                 = local.app_ci_role_name
  description          = "GitHub Actions role for the ${var.github_app_repo} repository: pushes the demo-app image to ECR on merges to main."
  permissions_boundary = var.permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_hostname}:aud" = "sts.amazonaws.com"
          "${local.oidc_hostname}:sub" = "repo:${var.github_org}/${var.github_app_repo}:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "app_ci_push" {
  name = "${local.app_ci_role_name}-ecr-push"
  role = aws_iam_role.app_ci.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # GetAuthorizationToken does not support resource-level scoping
        # (documented AWS constraint) — the "*" is the justified exception;
        # the token it returns grants nothing by itself.
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # Push plus the read actions docker needs for layer-existence checks
        # and the promotion step's digest lookup — all pinned to the one
        # repository this role exists to publish.
        Sid    = "PushDemoAppImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeImages",
        ]
        Resource = aws_ecr_repository.demo_app.arn
      },
    ]
  })
}
