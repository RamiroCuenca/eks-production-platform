# Attached policies, selected by the role's duty.
#
# apply_enabled = true  (dev: plan-on-PR + apply-on-merge) — a service-level
# allowlist of what the stack actually provisions, deliberately not
# AdministratorAccess: the boundary caps the catastrophic categories, and the
# allowlist keeps the role's blast radius legible at a glance. Services for
# later phases (secretsmanager, rds, elasticache) are intentionally absent
# until those phases land; gaps surface as clean AccessDenied errors and get
# added as one-line, reviewable diffs.
#
# apply_enabled = false (prod: plan-on-PR only) — AWS-managed ReadOnlyAccess
# for resource refresh, plus write access to the S3-native state lockfile
# (root.hcl sets use_lockfile = true; terraform plan acquires the lock).

resource "aws_iam_policy" "apply" {
  count = var.apply_enabled ? 1 : 0

  name        = "${local.role_name}-apply"
  description = "Service-scoped allowlist for plan + apply in ${var.environment}."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "InfraServiceAllowlist"
      Effect = "Allow"
      Action = [
        "autoscaling:*",
        "ec2:*",
        "eks:*",
        "elasticloadbalancing:*",
        "events:*",
        "iam:*",
        "kms:*",
        "logs:*",
        "s3:*",
        "sqs:*",
        "ssm:*",
        "sts:*",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apply" {
  count = var.apply_enabled ? 1 : 0

  role       = aws_iam_role.ci.name
  policy_arn = aws_iam_policy.apply[0].arn
}

resource "aws_iam_role_policy_attachment" "read_only" {
  count = var.apply_enabled ? 0 : 1

  role       = aws_iam_role.ci.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_policy" "state_lock" {
  count = var.apply_enabled ? 0 : 1

  name        = "${local.role_name}-state-lock"
  description = "S3-native state lockfile writes — the only mutation a plan-only role performs."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "StateLockfileWrite"
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:DeleteObject"]
      Resource = "arn:${data.aws_partition.current.partition}:s3:::${local.state_bucket}/*.tflock"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "state_lock" {
  count = var.apply_enabled ? 0 : 1

  role       = aws_iam_role.ci.name
  policy_arn = aws_iam_policy.state_lock[0].arn
}
