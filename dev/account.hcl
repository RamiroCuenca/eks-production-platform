# Variables specific to the dev environment.

locals {
  environment = "dev"

  common_tags = {
    Environment = "dev"
  }
}
