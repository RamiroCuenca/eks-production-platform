# Variables specific to the prod environment.

locals {
  environment = "prod"

  common_tags = {
    Environment = "prod"
  }
}
