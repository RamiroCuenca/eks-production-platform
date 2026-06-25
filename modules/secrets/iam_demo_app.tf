# Per-workload IRSA role for the demo application.
#
# This is the headline of the secrets phase: a role scoped to exactly ONE
# secret and ONE key, assumable only by one ServiceAccount in one namespace.
# Contrast modules/eks/iam_cilium_operator.tf, whose ENI actions MUST use
# Resource = "*" because ENIs are created dynamically and have no
# predeterminable ARN. Here the resources exist ahead of time, so they are
# named — the discipline is to scope to the ARN whenever it is knowable and
# treat "*" as the exception that must be justified at the call site.
locals {
  # OIDC condition keys use the issuer host without the scheme; strip https://
  # defensively (the provider's url attribute may or may not carry it).
  oidc_url_no_scheme = replace(var.oidc_provider_url, "https://", "")
}

resource "aws_iam_role" "demo_app_secrets" {
  name = "${var.name_prefix}-demo-app-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url_no_scheme}:aud" = "sts.amazonaws.com"
          "${local.oidc_url_no_scheme}:sub" = "system:serviceaccount:${var.demo_namespace}:${var.demo_service_account}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "demo_app_secrets" {
  name = "${var.name_prefix}-demo-app-secrets"
  role = aws_iam_role.demo_app_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadDemoSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        # Exact ARN, including the random suffix Secrets Manager appends —
        # available here because Terraform creates the secret. No wildcard.
        Resource = aws_secretsmanager_secret.demo.arn
      },
      {
        Sid    = "DecryptDemoSecretViaSecretsManager"
        Effect = "Allow"
        Action = "kms:Decrypt"
        # Scoped to the one app-secrets key AND only usable when the call is
        # brokered by Secrets Manager — never for arbitrary decryption.
        Resource = aws_kms_key.app_secrets.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      },
    ]
  })
}
