# Dedicated customer-managed key for application secrets.
#
# Kept separate from the cluster's EKS-Secrets envelope CMK (modules/eks): app
# secrets and Kubernetes-Secret envelope encryption have independent blast
# radius and rotation stories, and coupling them would mean an app-secret
# key-policy edit touching the cluster's Secret-encryption key. Using a CMK
# rather than the AWS-managed aws/secretsmanager key is deliberate — it forces
# the workload's IRSA policy to carry an explicit kms:Decrypt grant (see
# iam_demo_app.tf), the realistic production shape and the security-depth point
# of this module.
resource "aws_kms_key" "app_secrets" {
  description             = "Application secrets encryption key for ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # The key policy grants only the account root, delegating authorization to IAM
  # identity policies (the canonical AWS pattern). The IRSA role's identity
  # policy in iam_demo_app.tf grants the actual kms:Decrypt, scoped by a
  # kms:ViaService condition to Secrets Manager — so this key can never be used
  # for arbitrary decryption, only when brokered by the service holding the
  # secret.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableIAMUserPermissions"
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_kms_alias" "app_secrets" {
  name          = "alias/${var.name_prefix}-app-secrets"
  target_key_id = aws_kms_key.app_secrets.key_id
}
