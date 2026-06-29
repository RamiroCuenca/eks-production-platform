# Shipped so `terraform validate` works on this module standalone in CI
# (-backend=false, no Terragrunt). At instantiation, root.hcl's generated
# versions.tf overwrites this with the platform-wide provider pins (if_exists =
# "overwrite"), so the constraint here only governs the standalone-validate path.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.51"
    }
  }
}
