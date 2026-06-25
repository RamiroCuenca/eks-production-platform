variable "name_prefix" {
  description = "Prefix for all owned resources. Provided by root.hcl, format: project-environment-region. Also equals the EKS cluster name."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod). Used in the secret's hierarchical name so dev and prod secrets never collide and the path reads self-describingly."
  type        = string
}

variable "aws_region" {
  description = "AWS region the cluster and secret live in. Used for the Secrets Manager interface endpoint service name and the kms:ViaService condition that constrains the IRSA role's decrypt grant to Secrets-Manager-brokered calls."
  type        = string
}

# ---------- EKS wiring (from the eks module via the Terragrunt dependency) ----------

variable "oidc_provider_arn" {
  description = "Cluster IAM OIDC provider ARN. The demo-app IRSA role's trust policy federates to this provider. Dependency-passed (not data-sourced) so plan-all works on a fresh stack before the cluster exists."
  type        = string
}

variable "oidc_provider_url" {
  description = "Cluster OIDC issuer URL. The trust-policy sub/aud conditions key off the host portion (scheme stripped defensively)."
  type        = string
}

# ---------- Network wiring (from the network module via the Terragrunt dependency) ----------

variable "vpc_id" {
  description = "VPC the Secrets Manager interface endpoint is created in."
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR. The interface endpoint's security group allows 443 from this range so any in-VPC pod ENI or node can reach the Secrets Manager API on the AWS backbone; IAM still gates every call."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (map AZ -> subnet ID) the interface endpoint places its ENIs in."
  type        = map(string)
}

# ---------- Demo workload identity (must match the gitops demo chart) ----------

variable "demo_namespace" {
  description = "Kubernetes namespace the demo workload runs in. Must match the namespace the gitops demo chart deploys into (the default-deny `demo` namespace). Used verbatim in the IRSA trust policy sub claim."
  type        = string
  default     = "demo"
}

variable "demo_service_account" {
  description = "ServiceAccount name the demo workload uses. Must match the SA the gitops demo chart creates and annotates with the role ARN. Used verbatim in the IRSA trust policy sub claim."
  type        = string
  default     = "demo-app"
}
