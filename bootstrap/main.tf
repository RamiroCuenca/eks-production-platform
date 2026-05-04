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

# DynamoDB table for Terragrunt state locking. Pay-per-request avoids idle
# cost; lock writes are infrequent and small.
resource "aws_dynamodb_table" "tflock" {
  for_each = var.environments

  name         = "${var.project}-${each.key}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Environment = each.key
  }
}
