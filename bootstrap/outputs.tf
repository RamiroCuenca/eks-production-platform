output "state_buckets" {
  description = "Names of the S3 buckets holding Terraform/Terragrunt state, keyed by environment."
  value       = { for env, bucket in aws_s3_bucket.tfstate : env => bucket.id }
}

output "lock_tables" {
  description = "Names of the DynamoDB tables used for Terragrunt state locking, keyed by environment."
  value       = { for env, table in aws_dynamodb_table.tflock : env => table.id }
}
