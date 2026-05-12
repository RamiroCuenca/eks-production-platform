# Variables specific to ap-northeast-2 (Seoul).

locals {
  aws_region = "ap-northeast-2"
  azs        = ["ap-northeast-2a", "ap-northeast-2c"]

  common_tags = {
    Region = "ap-northeast-2"
  }
}
