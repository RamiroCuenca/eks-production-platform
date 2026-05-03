variable "project" {
  description = "Project prefix used in resource names and tags."
  type        = string
  default     = "eks-platform"
}

variable "environments" {
  description = "Environments to provision state primitives for."
  type        = set(string)
  default     = ["dev", "prod"]
}

variable "aws_region" {
  description = "Region where state primitives live (the platform's primary region)."
  type        = string
  default     = "ap-northeast-1"
}
