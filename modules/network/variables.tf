variable "name_prefix" {
  description = "Prefix used for the VPC and subnet Name tags. Provided by root.hcl, format: project-environment-region."
  type        = string
}

variable "aws_region" {
  description = "AWS region the VPC lives in. Used to derive gateway-endpoint service names."
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR. A /16 is expected — the module carves six /20 subnets out of it (public/private/intra × number of AZs)."
  type        = string
}

variable "azs" {
  description = "Availability Zones to span. Each AZ receives one public, one private, and one intra subnet."
  type        = list(string)
}

variable "enable_flow_logs" {
  description = "Whether to emit VPC flow logs to CloudWatch."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention for the VPC flow logs CloudWatch log group."
  type        = number
  default     = 30
}
