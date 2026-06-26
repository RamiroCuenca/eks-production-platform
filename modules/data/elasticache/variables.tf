variable "name_prefix" {
  description = "Prefix for all owned resources. Provided by root.hcl, format: project-environment-region. Also equals the EKS cluster name."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod). Used in the connection secret's hierarchical name so dev and prod never collide."
  type        = string
}

variable "aws_region" {
  description = "AWS region the cache lives in. Surfaced in the connection secret for clients."
  type        = string
}

# ---------- Network wiring (from the network module via the Terragrunt dependency) ----------

variable "vpc_id" {
  description = "VPC the data tier runs in. The Redis security group is created here."
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR. Retained for the documented VPC-CIDR ingress fallback if Cilium ENI-IPAM pod ENIs turn out not to carry the cluster security group."
  type        = string
}

variable "intra_subnet_ids" {
  description = "Intra subnet IDs (map AZ -> subnet ID). No route to a NAT or internet gateway, so the cache cannot initiate outbound internet traffic."
  type        = map(string)
}

# ---------- EKS wiring (from the eks module via the Terragrunt dependency) ----------

variable "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID. The Redis ingress rule references this so only traffic from the cluster can reach 6379."
  type        = string
}

# ---------- Cache shape (sized per environment from account.hcl) ----------

variable "redis_engine_version" {
  description = "Redis engine version. Pinned and bumped via PR. Must agree with redis_parameter_group_name's major version."
  type        = string
  default     = "7.1"
}

variable "redis_parameter_group_name" {
  description = "Parameter group. default.redis7 is the cluster-mode-DISABLED family for Redis 7.x (cluster-mode-enabled would be default.redis7.cluster.on)."
  type        = string
  default     = "default.redis7"
}

variable "redis_node_type" {
  description = "Cache node instance type. Small Graviton in dev; scaled up in prod via account.hcl."
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_num_cache_clusters" {
  description = "Total nodes in the single node group: 1 primary + (n-1) replicas. Two (primary + one replica in another AZ) is the minimum for Multi-AZ automatic failover; prod runs more."
  type        = number
  default     = 2
}

variable "redis_snapshot_retention" {
  description = "Days to retain automatic snapshots. Zero in dev (build-screenshot-destroy); positive in prod."
  type        = number
  default     = 0
}
