# Variables specific to ap-northeast-1 (Tokyo).

locals {
  aws_region = "ap-northeast-1"
  azs        = ["ap-northeast-1a", "ap-northeast-1c"]

  common_tags = {
    Region = "ap-northeast-1"
  }
}
