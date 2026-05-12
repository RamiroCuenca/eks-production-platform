output "state_buckets" {
  description = "Names of the S3 buckets holding Terraform/Terragrunt state, keyed by environment. Each bucket also hosts the native S3 lockfile object used for state locking."
  value       = { for env, bucket in aws_s3_bucket.tfstate : env => bucket.id }
}
