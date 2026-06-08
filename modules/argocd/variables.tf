variable "name_prefix" {
  description = "Provided by root.hcl, format: project-environment-region. Not used as a resource prefix here (ArgoCD's resource names are chart-managed), but kept in the variable set for parity with sibling modules."
  type        = string
}

variable "aws_region" {
  description = "AWS region the cluster lives in. Used by the EKS get-token exec plugin in the providers configuration."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod). Stamped onto the cluster Secret as the `env` label so gitops-repo ApplicationSets can select clusters by environment."
  type        = string
}

# ---------- EKS wiring (from eks module via dependency block) ----------

variable "cluster_name" {
  description = "Name of the EKS cluster ArgoCD runs in. The cluster Secret carries this value forward to the gitops repo's Karpenter chart for tag-based subnet/SG discovery."
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS API server endpoint. Passed in via the Terragrunt dependency on the eks module rather than read from a data source — data sources resolve at plan time and would fail on a fresh stack where the cluster doesn't exist yet."
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA. Same rationale as cluster_endpoint: dependency-passed to avoid plan-time AWS reads against a not-yet-existing cluster."
  type        = string
}

variable "karpenter_controller_role_arn" {
  description = "IRSA role ARN annotated onto the Karpenter ServiceAccount by the Karpenter Helm chart in the gitops repo. Propagated via the cluster Secret."
  type        = string
}

variable "karpenter_node_role_name" {
  description = "IAM role NAME assumed by Karpenter-launched EC2 instances. Karpenter v1's EC2NodeClass.spec.role takes a name (Karpenter manages the instance profile itself). Propagated via the cluster Secret."
  type        = string
}

variable "karpenter_interruption_queue_name" {
  description = "SQS queue name Karpenter polls for spot interruption warnings. Propagated via the cluster Secret."
  type        = string
}

# ---------- ArgoCD configuration ----------

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version. Pin explicitly; the chart's value schema occasionally changes across minor versions."
  type        = string
  default     = "7.8.2"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace ArgoCD runs in. The cluster Secret must live in this namespace for the ApplicationSet controller to read it."
  type        = string
  default     = "argocd"
}

variable "gitops_repo_url" {
  description = "HTTPS clone URL of the gitops repository that holds the ApplicationSets and Helm charts ArgoCD reconciles. Public repo — no credential Secret required."
  type        = string
}

variable "gitops_repo_target_revision" {
  description = "Branch, tag, or commit SHA the root Application tracks in the gitops repo."
  type        = string
  default     = "main"
}

variable "ha_enabled" {
  description = "Enable ArgoCD's HA topology (redis-ha + multi-replica controllers and server). Default false for dev; prod should set true."
  type        = bool
  default     = false
}
