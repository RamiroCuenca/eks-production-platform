# Workload identities for the Go demo application — two roles, split by
# privilege, both following iam_demo_app.tf's discipline: exact secret ARNs,
# kms:Decrypt only via Secrets Manager, one ServiceAccount per role.
#
# Runtime (go-demo):     the app user's DB credential + the Redis connection
#                        secret (AUTH token). Cannot read the master secret.
# Db-init (go-demo-db-init): the RDS-managed master secret + the app user's
#                        credential — everything the one-shot Job needs to
#                        CREATE the least-privilege user, nothing the running
#                        app holds. The split is the point: a compromised app
#                        pod cannot escalate to the master login.

# ---------- Runtime ----------

resource "aws_iam_role" "go_demo" {
  name = "${var.name_prefix}-go-demo"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url_no_scheme}:aud" = "sts.amazonaws.com"
          "${local.oidc_url_no_scheme}:sub" = "system:serviceaccount:${var.demo_namespace}:${var.go_demo_service_account}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "go_demo" {
  name = "${var.name_prefix}-go-demo"
  role = aws_iam_role.go_demo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadRuntimeSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = [
          aws_secretsmanager_secret.go_demo_db.arn,
          var.redis_connection_secret_arn,
        ]
      },
      {
        Sid    = "DecryptRuntimeSecretsViaSecretsManager"
        Effect = "Allow"
        Action = "kms:Decrypt"
        Resource = [
          aws_kms_key.app_secrets.arn,
          var.redis_kms_key_arn,
        ]
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      },
    ]
  })
}

# ---------- Db-init ----------

resource "aws_iam_role" "go_demo_db_init" {
  name = "${var.name_prefix}-go-demo-db-init"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url_no_scheme}:aud" = "sts.amazonaws.com"
          "${local.oidc_url_no_scheme}:sub" = "system:serviceaccount:${var.demo_namespace}:${var.go_demo_db_init_service_account}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "go_demo_db_init" {
  name = "${var.name_prefix}-go-demo-db-init"
  role = aws_iam_role.go_demo_db_init.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadInitSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = [
          var.aurora_master_secret_arn,
          aws_secretsmanager_secret.go_demo_db.arn,
        ]
      },
      {
        Sid    = "DecryptInitSecretsViaSecretsManager"
        Effect = "Allow"
        Action = "kms:Decrypt"
        Resource = [
          var.aurora_kms_key_arn,
          aws_kms_key.app_secrets.arn,
        ]
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      },
    ]
  })
}
