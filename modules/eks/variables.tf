variable "name_prefix" {
  description = "Prefix used for cluster name and all owned resources. Provided by root.hcl, format: project-environment-region."
  type        = string
}

variable "aws_region" {
  description = "AWS region the cluster lives in. Used for region-scoped resources (KMS key alias, SQS queue) and for service-name composition."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod). Surfaced in tags and used to scope a small number of env-conditional defaults."
  type        = string
}

# ---------- VPC wiring (from network module via dependency block) ----------

variable "vpc_id" {
  description = "VPC the cluster runs in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs the EKS control plane ENIs and managed/Karpenter node groups attach to. Map AZ -> subnet ID."
  type        = map(string)
}

# ---------- Cluster shape ----------

variable "cluster_version" {
  description = "EKS Kubernetes version. Required, no default — every upgrade must be an explicit edit visible in PR diffs."
  type        = string
}

variable "api_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Permissive on dev, allowlisted on prod (operator IP + GitHub Actions OIDC ranges)."
  type        = list(string)
}

variable "cluster_log_retention_days" {
  description = "CloudWatch retention for the EKS control plane log group. 30 days matches the VPC flow-logs retention; prod can override."
  type        = number
  default     = 30
}

# ---------- Authentication ----------

variable "operator_iam_arn" {
  description = "IAM principal that receives the cluster-admin access entry on this cluster. If empty, the module falls back to the IAM identity running terraform apply via aws_caller_identity — convenient for local-only workflows, unsafe once CI also applies, so prefer setting OPERATOR_IAM_ARN in the shell."
  type        = string
  default     = ""
}

variable "additional_access_entries" {
  description = "Extra IAM-to-cluster bindings. Keyed by an arbitrary stable name. Each entry maps an IAM principal to one AWS-managed EKS access policy at cluster scope. Populated in later phases (GitHub Actions OIDC role)."
  type = map(object({
    principal_arn = string
    policy_arn    = string
  }))
  default = {}
}

# ---------- System managed node group ----------

variable "system_node_instance_types" {
  description = "Instance types for the system managed node group. Small Graviton instances by default — the system NG hosts kube-system controllers, the Karpenter controller, ArgoCD, and observability agents, none of which need much capacity."
  type        = list(string)
  default     = ["m7g.large"]
}

variable "system_node_desired_size" {
  description = "Desired size of the system managed node group. Two by default so Karpenter and other controllers survive a single AZ outage."
  type        = number
  default     = 2
}

variable "system_node_min_size" {
  description = "Minimum size of the system managed node group."
  type        = number
  default     = 2
}

variable "system_node_max_size" {
  description = "Maximum size of the system managed node group. Stays small intentionally — application capacity belongs to Karpenter, not this pool."
  type        = number
  default     = 4
}

variable "system_node_disk_size" {
  description = "Root EBS volume size (GiB) for system node group instances."
  type        = number
  default     = 50
}

# ---------- Karpenter AWS scaffolding ----------

variable "karpenter_namespace" {
  description = "Kubernetes namespace the Karpenter controller will run in. Used for the controller's IRSA trust policy. The Helm chart in the gitops repo must install Karpenter into this same namespace."
  type        = string
  default     = "karpenter"
}

variable "karpenter_service_account" {
  description = "Kubernetes ServiceAccount the Karpenter controller will use. Bound to the controller IAM role via IRSA."
  type        = string
  default     = "karpenter"
}
