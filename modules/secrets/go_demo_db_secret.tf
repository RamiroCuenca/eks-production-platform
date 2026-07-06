# Application database credential for the Go demo workload.
#
# The db-init Job (running as the go-demo-db-init identity, see
# iam_go_demo.tf) reads this secret alongside the RDS-managed master secret
# and provisions the least-privilege database user with it; the runtime app
# then authenticates as that user, never as master.
#
# Same provenance rules as the standalone demo secret: the value is generated,
# never hand-typed or committed, lives only in Terraform state and Secrets
# Manager, and recovery_window_in_days = 0 keeps teardown symmetric with
# apply. A real credential would be seeded out-of-band — called out in the
# README.

locals {
  go_demo_db_secret_name = "eks-platform/${var.environment}/go-demo/db-credentials"
}

resource "aws_secretsmanager_secret" "go_demo_db" {
  name                    = local.go_demo_db_secret_name
  description             = "Least-privilege Aurora user for the Go demo app. Created in the database by the db-init Job; generated value, never committed."
  kms_key_id              = aws_kms_key.app_secrets.arn
  recovery_window_in_days = 0
}

resource "random_password" "go_demo_db" {
  length = 32
  # Exclude characters that complicate SQL-literal and shell handling in the
  # init Job without materially reducing entropy at length 32.
  override_special = "!#%*-_=+"
}

resource "aws_secretsmanager_secret_version" "go_demo_db" {
  secret_id = aws_secretsmanager_secret.go_demo_db.id
  secret_string = jsonencode({
    username = var.go_demo_db_username
    password = random_password.go_demo_db.result
  })
}
