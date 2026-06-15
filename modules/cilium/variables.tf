variable "name_prefix" {
  description = "Provided by root.hcl, format: project-environment-region. Used as the prefix for the operator IRSA role name."
  type        = string
}

variable "aws_region" {
  description = "AWS region the cluster lives in. Used by the EKS get-token exec plugin in the providers configuration."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod). Surfaced in tags and available for env-conditional sizing."
  type        = string
}

# ---------- EKS wiring (from eks module via dependency block) ----------

variable "cluster_name" {
  description = "Name of the EKS cluster Cilium runs in. Used for the CoreDNS addon and the get-token exec plugin."
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS API server endpoint. Dependency-passed from the eks module (not a data source) so plan works on a fresh stack. Also fed to Cilium as k8sServiceHost — with kube-proxy removed there is no in-cluster kube-proxy to program the kubernetes.default service, so Cilium must reach the API server directly."
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA. Dependency-passed for the same plan-time reason as cluster_endpoint."
  type        = string
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the cluster. The Cilium operator IRSA trust policy references this."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL (with https:// prefix as exported by the eks module). The trust policy strips the scheme for the sub/aud conditions."
  type        = string
}

# ---------- Cilium configuration ----------

variable "cilium_version" {
  description = "Cilium Helm chart version. Pin explicitly and VERIFY against the cluster's Kubernetes version in the Cilium support matrix before applying — a chart that predates the k8s minor can fail subtly at runtime. Bumped via PR like every other pinned dependency."
  type        = string
  default     = "1.17.4"
}

variable "cilium_operator_replicas" {
  description = "Replica count for the Cilium operator. One is sufficient for dev; prod can raise to 2 for HA (the operator is the only component that allocates ENIs, so a brief gap during a node loss is tolerable but HA is cleaner in prod)."
  type        = number
  default     = 1
}

variable "hubble_ui_enabled" {
  description = "Enable the Hubble UI. On for the portfolio (the flow graph is a key observability screenshot); exposed via port-forward only, never a public LoadBalancer."
  type        = bool
  default     = true
}

# ---------- CoreDNS addon (relocated from the eks module) ----------

variable "coredns_addon_version" {
  description = "Optional pinned version for the CoreDNS managed addon. Empty string lets EKS pick the default-compatible version for the cluster's Kubernetes version, which is the right default for a build-screenshot-destroy lifecycle."
  type        = string
  default     = ""
}
