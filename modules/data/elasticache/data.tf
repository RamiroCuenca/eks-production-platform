# Account ID + partition for the KMS key policy's root principal ARN. Both
# resolve locally without reaching AWS APIs, so they are safe at plan time on a
# fresh stack.
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}
