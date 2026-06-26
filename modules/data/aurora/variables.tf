variable "name_prefix" {
  description = "Prefix for all owned resources. Provided by root.hcl, format: project-environment-region. Also equals the EKS cluster name."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod). Used in the connection secret's hierarchical name so dev and prod never collide."
  type        = string
}

variable "aws_region" {
  description = "AWS region the cluster lives in. Surfaced in the connection secret for clients that build region-scoped endpoints."
  type        = string
}

# ---------- Network wiring (from the network module via the Terragrunt dependency) ----------

variable "vpc_id" {
  description = "VPC the data tier runs in. The Aurora security group is created here."
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR. Retained for the documented VPC-CIDR ingress fallback if Cilium ENI-IPAM pod ENIs turn out not to carry the cluster security group."
  type        = string
}

variable "intra_subnet_ids" {
  description = "Intra subnet IDs (map AZ -> subnet ID). These subnets have no route to a NAT or internet gateway, so Aurora cannot initiate outbound internet traffic — the strongest isolation tier."
  type        = map(string)
}

# ---------- EKS wiring (from the eks module via the Terragrunt dependency) ----------

variable "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID. The Aurora ingress rule references this so only traffic from the cluster (carried on node/pod ENIs that inherit this SG under Cilium ENI IPAM) can reach 5432."
  type        = string
}

# ---------- Cluster shape (sized per environment from account.hcl) ----------

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version. Pinned and bumped via PR like cluster_version. Must agree with aurora_parameter_group_family's major version."
  type        = string
  default     = "16.6"
}

variable "aurora_parameter_group_family" {
  description = "Cluster parameter group family. Must track the engine major version (aurora-postgresql16 for engine 16.x)."
  type        = string
  default     = "aurora-postgresql16"
}

variable "aurora_instance_class" {
  description = "Instance class for every cluster instance. Small Graviton in dev; scaled up in prod via account.hcl."
  type        = string
  default     = "db.t4g.medium"
}

variable "aurora_instance_count" {
  description = "Number of cluster instances. Two (a writer + one reader in a separate AZ) is the minimum that demonstrates Multi-AZ failover; prod runs more."
  type        = number
  default     = 2
}

variable "database_name" {
  description = "Initial database created in the cluster. The demo app reads from this database."
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master username. The password is managed and rotated by RDS in Secrets Manager (manage_master_user_password), never set here."
  type        = string
  default     = "dbadmin"
}

# ---------- Backups / protection (sized per environment) ----------

variable "aurora_backup_retention" {
  description = "Automated backup retention in days. Short in dev (build-screenshot-destroy); longer in prod."
  type        = number
  default     = 1
}

variable "aurora_deletion_protection" {
  description = "Block accidental cluster deletion. False in dev so terragrunt destroy is clean; true in prod."
  type        = bool
  default     = false
}

variable "aurora_skip_final_snapshot" {
  description = "Skip the final snapshot on delete. True in dev (symmetric teardown); false in prod so a destroy captures a final snapshot."
  type        = bool
  default     = true
}

variable "aurora_performance_insights_enabled" {
  description = "Enable Performance Insights (free 7-day tier). Supported on db.t4g.medium and above. Encrypted with the module CMK when on."
  type        = bool
  default     = true
}
