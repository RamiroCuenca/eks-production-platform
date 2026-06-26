# Dedicated customer-managed key for the Aurora data store.
#
# Kept separate from the EKS-envelope CMK (modules/eks), the app-secrets CMK
# (modules/secrets), and the ElastiCache CMK: each store owns its key so blast
# radius and rotation stay independent and the module carries no cross-module
# KMS dependency. This key encrypts THREE things — the cluster storage volume
# (kms_key_id), the RDS-managed master-password secret
# (master_user_secret_kms_key_id), and the Terraform-written connection secret —
# so a key the platform owns and can audit covers the entire Aurora data path.
resource "aws_kms_key" "aurora" {
  description             = "Aurora PostgreSQL encryption key for ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # Root-only key policy, delegating authorization to IAM identity policies (the
  # canonical AWS pattern, same shape as modules/secrets). RDS-managed master
  # password creation, storage encryption, and the connection-secret writes are
  # all performed within this account, so the root grant covers them. If the
  # RDS-managed secret ever fails to create on a KMS access error, add a
  # statement permitting secretsmanager via a kms:ViaService condition.
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

resource "aws_kms_alias" "aurora" {
  name          = "alias/${var.name_prefix}-aurora"
  target_key_id = aws_kms_key.aurora.key_id
}
