locals {
  cluster_name = var.name_prefix

  # Fall back to the IAM identity running apply when the operator ARN isn't
  # set via env var. See variables.tf for the safety tradeoff.
  operator_iam_arn = var.operator_iam_arn != "" ? var.operator_iam_arn : data.aws_caller_identity.current.arn

  subnet_ids = values(var.private_subnet_ids)

  # EKS-required Karpenter discovery tag — Karpenter selects subnets and
  # security groups via this tag from EC2NodeClass `subnetSelectorTerms` /
  # `securityGroupSelectorTerms`. Applied to the cluster security group below
  # and to each private subnet via aws_ec2_tag (the subnets themselves are
  # owned by the network module, so we tag them in place rather than redefine).
  karpenter_discovery_tag = {
    "karpenter.sh/discovery" = local.cluster_name
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# ---------- Cluster secret envelope encryption (CMK) ----------

# Per-cluster customer-managed KMS key for Kubernetes Secrets envelope
# encryption. Decrypting a secret requires both etcd access AND kms:Decrypt
# on this key — defense-in-depth beyond the default aws/ebs-encrypted etcd
# volume. Enabling envelope encryption on EKS is one-way; once set, it
# cannot be removed without rebuilding the cluster.
resource "aws_kms_key" "cluster" {
  description             = "EKS Secrets envelope encryption key for ${local.cluster_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountRootAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "EKSServiceUse"
        Effect    = "Allow"
        Principal = { Service = "eks.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_kms_alias" "cluster" {
  name          = "alias/${local.cluster_name}-eks-secrets"
  target_key_id = aws_kms_key.cluster.key_id
}

# ---------- Control plane log group (pre-created) ----------

# Pre-creating the log group is non-negotiable: if EKS auto-creates it, the
# retention defaults to "Never expire". Owning the resource here lets us set
# retention explicitly and recreate the cluster without losing the group.
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days
}

# ---------- EKS cluster ----------

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  # Access entries only. Default cluster-creator-admin is off so that operator
  # access is granted through an explicit, auditable access_entry resource,
  # not an invisible implicit grant to whoever first ran apply.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = local.subnet_ids
    endpoint_private_access = true
    # Public endpoint is deliberate: operator access during the
    # build-screenshot-destroy lifecycle comes from changing networks, and a
    # private-only endpoint would require a standing bastion or VPN. The API
    # is still IAM-authenticated via access entries, and prod narrows
    # public_access_cidrs to operator + CI ranges (see prod/account.hcl).
    #trivy:ignore:AVD-AWS-0040
    endpoint_public_access = true
    public_access_cidrs    = var.api_public_access_cidrs
  }

  # Envelope encryption for Kubernetes Secrets. One-way switch.
  encryption_config {
    provider {
      key_arn = aws_kms_key.cluster.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.cluster,
  ]
}

# ---------- IRSA OIDC provider ----------

# IRSA is wired by attaching an IAM OIDC provider to the cluster's OIDC
# issuer URL. Pods assume IAM roles via projected JWT + AssumeRoleWithWebIdentity.
# Independent of authentication_mode (which controls inbound IAM-to-K8s).
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
}

# ---------- Karpenter subnet discovery tags ----------

# Karpenter discovers eligible subnets by tag. The subnets are owned by the
# network module, so we attach the discovery tag here as a side-effect tag
# rather than redefining the subnet. This couples the tag's lifecycle to the
# cluster — destroying the cluster removes the tag, not the subnet.
resource "aws_ec2_tag" "subnet_karpenter_discovery" {
  for_each = var.private_subnet_ids

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

# Karpenter also discovers the cluster security group by the same tag.
resource "aws_ec2_tag" "cluster_sg_karpenter_discovery" {
  resource_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}
