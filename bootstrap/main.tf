provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      Component = "state-bootstrap"
      ManagedBy = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

# State bucket — versioned, encrypted, public access blocked.
#
# force_destroy = true is intentional for the portfolio's build → screenshot →
# destroy lifecycle: it lets `terraform destroy` purge versioned state objects
# cleanly. In a real production deployment this should be false on the prod
# bucket — losing state-file versions accidentally is catastrophic.
resource "aws_s3_bucket" "tfstate" {
  for_each = var.environments

  bucket        = "${data.aws_caller_identity.current.account_id}-${var.project}-${each.key}-tfstate"
  force_destroy = true

  tags = {
    Environment = each.key
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  for_each = var.environments

  bucket = aws_s3_bucket.tfstate[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES256) instead of a customer-managed KMS key is deliberate:
# encryption at rest is still enforced, and a CMK would add monthly key cost
# plus key-policy management with no compliance driver at this scope. State
# access is already gated by IAM and the public-access block. Revisit if
# state ever needs audited key usage (CloudTrail per-decrypt logging).
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  for_each = var.environments

  bucket = aws_s3_bucket.tfstate[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  for_each = var.environments

  bucket = aws_s3_bucket.tfstate[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State locking is handled by Terraform's S3-native lockfile mechanism
# (use_lockfile = true in the backend config), so no DynamoDB table is
# provisioned here. S3 conditional writes serialize concurrent applies
# directly against a sibling lock object in the same bucket.
