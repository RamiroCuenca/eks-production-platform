# Permissions boundary for the CI role.
#
# A boundary grants nothing by itself — effective permissions are the
# intersection of the boundary and the attached policies — so the ceiling
# Allow * statement is required; without it the role could do nothing at all.
# The value is the Deny statements: no matter what a future PR attaches to
# the role, these actions stay off the table.

resource "aws_iam_policy" "permissions_boundary" {
  name        = local.boundary_name
  description = "Caps the ${local.role_name} CI role regardless of attached policies: region pinning, no long-lived credentials, no KMS/account/billing destruction, no boundary tampering."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PermissionsCeiling"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
      {
        # IAM and STS are global services whose calls resolve to us-east-1,
        # so a blanket region deny would block them entirely; their dangerous
        # actions are denied explicitly below instead.
        Sid       = "DenyOutsideAllowedRegions"
        Effect    = "Deny"
        NotAction = ["iam:*", "sts:*"]
        Resource  = "*"
        Condition = {
          StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions }
        }
      },
      {
        # CI must never mint credentials that outlive the workflow run.
        Sid      = "DenyLongLivedCredentials"
        Effect   = "Deny"
        Action   = ["iam:CreateUser", "iam:CreateAccessKey", "iam:CreateLoginProfile"]
        Resource = "*"
      },
      {
        Sid      = "DenyAccountAliasChanges"
        Effect   = "Deny"
        Action   = ["iam:CreateAccountAlias", "iam:DeleteAccountAlias"]
        Resource = "*"
      },
      {
        Sid      = "DenyKmsKeyDestruction"
        Effect   = "Deny"
        Action   = ["kms:ScheduleKeyDeletion", "kms:DisableKey"]
        Resource = "*"
      },
      {
        Sid      = "DenyAccountAndBillingMutation"
        Effect   = "Deny"
        Action   = ["aws-portal:*", "account:*", "billing:*", "organizations:*"]
        Resource = "*"
      },
      {
        Sid      = "DenyBoundaryDetachment"
        Effect   = "Deny"
        Action   = ["iam:PutRolePermissionsBoundary", "iam:DeleteRolePermissionsBoundary"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/${var.project}-ci-*"
      },
      {
        # Without this, a policy edit could neutralise every Deny above by
        # publishing a new default version of the boundary itself.
        Sid    = "DenyBoundaryPolicyMutation"
        Effect = "Deny"
        Action = [
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:DeletePolicy",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:policy/${var.project}-ci-*-boundary"
      },
    ]
  })
}
