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

# ---------- Secrets wiring (from the secrets module via dependency block) ----------

variable "demo_app_secrets_role_arn" {
  description = "IRSA role ARN the gitops demo chart annotates onto the demo ServiceAccount so the ASCP provider can assume it. Account-specific, so it crosses into the public gitops repo only through this cluster Secret. Propagated via the cluster Secret."
  type        = string
}

variable "demo_secret_name" {
  description = "Secrets Manager secret name the gitops demo SecretProviderClass references as its objectName. Env-specific (dev/prod in the path). Propagated via the cluster Secret."
  type        = string
}

variable "go_demo_secrets_role_arn" {
  description = "Runtime IRSA role ARN for the Go demo app's ServiceAccount. Account-specific. Propagated via the cluster Secret."
  type        = string
}

variable "go_demo_db_init_role_arn" {
  description = "IRSA role ARN for the database-init Job's ServiceAccount — the only identity that may read the RDS master secret. Propagated via the cluster Secret."
  type        = string
}

variable "go_demo_db_secret_name" {
  description = "Name of the generated app-user DB credential secret, referenced as a SecretProviderClass objectName by the go-demo chart. Propagated via the cluster Secret."
  type        = string
}

variable "go_demo_db_username" {
  description = "Least-privilege DB username the app authenticates as. Bridged so the chart's DB_USER env shares one source with the credential secret's contents."
  type        = string
}

# ---------- Data-tier wiring (from the aurora/elasticache modules via dependency blocks) ----------

variable "aurora_master_secret_arn" {
  description = "ARN of the RDS-managed master secret. Bridged as an ARN (not a name) because RDS generates the name; ASCP accepts full ARNs as objectName. Consumed only by the db-init Job's SecretProviderClass."
  type        = string
}

variable "aurora_writer_endpoint" {
  description = "Aurora writer endpoint hostname. Apply-generated, non-secret — becomes the app's DB_HOST env via the cluster Secret rather than a hardcoded value that would drift."
  type        = string
}

variable "aurora_port" {
  description = "PostgreSQL port. Bridged as a string (annotation values must be strings)."
  type        = string
}

variable "aurora_database_name" {
  description = "Initial database name the app connects to (DB_NAME env)."
  type        = string
}

variable "redis_primary_endpoint" {
  description = "ElastiCache primary endpoint hostname. Becomes the host part of the app's REDIS_ADDR env."
  type        = string
}

variable "redis_port" {
  description = "Redis port. Bridged as a string (annotation values must be strings)."
  type        = string
}

variable "redis_connection_secret_name" {
  description = "Name of the Redis connection secret whose auth_token key the go-demo SecretProviderClass extracts (jmesPath) into the mounted REDIS_PASSWORD file."
  type        = string
}

# ---------- Registry wiring (from the ecr module via dependency block) ----------

variable "ecr_repository_url" {
  description = "Full ECR repository URL for the demo-app image. Embeds the account ID, so it crosses into the public gitops repo only through the cluster Secret; CI promotes only the tag."
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
