# Dedicated customer-managed key for the ElastiCache data store.
#
# Separate from every other CMK in the platform (EKS envelope, app-secrets,
# Aurora) so the cache's at-rest encryption and AUTH-token secret have an
# independent blast radius and rotation story, and the module stays
# self-contained with no cross-module KMS dependency. Encrypts both the Redis
# at-rest data and the Terraform-written connection/AUTH secret.
resource "aws_kms_key" "redis" {
  description             = "ElastiCache Redis encryption key for ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # Root-only key policy, delegating authorization to IAM identity policies (the
  # canonical AWS pattern, same shape as modules/secrets and modules/data/aurora).
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

resource "aws_kms_alias" "redis" {
  name          = "alias/${var.name_prefix}-redis"
  target_key_id = aws_kms_key.redis.key_id
}
