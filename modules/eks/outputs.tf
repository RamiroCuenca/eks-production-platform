output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA cert for the cluster — needed to configure kubectl / Helm against the API server."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "EKS Kubernetes version actually provisioned."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Cluster security group created by EKS. Other modules attach rules here to permit traffic to/from the control plane."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the cluster. IRSA trust policies in other modules reference this."
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL (without the https:// prefix is what trust-policy conditions need)."
  value       = aws_iam_openid_connect_provider.cluster.url
}

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key that envelope-encrypts Kubernetes Secrets for this cluster."
  value       = aws_kms_key.cluster.arn
}

# ---------- Karpenter outputs (consumed by the gitops repo / Helm values) ----------

output "karpenter_controller_role_arn" {
  description = "IAM role ARN the Karpenter ServiceAccount must annotate with eks.amazonaws.com/role-arn so the controller authenticates via IRSA."
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN that Karpenter-launched EC2 instances assume."
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_node_role_name" {
  description = "IAM role NAME (not ARN) that Karpenter-launched EC2 instances assume. Karpenter v1's EC2NodeClass.spec.role takes a role name; Karpenter manages the instance profile itself, so the gitops chart only needs the name."
  value       = aws_iam_role.karpenter_node.name
}

output "karpenter_node_instance_profile_name" {
  description = "Instance profile name referenced by Karpenter's EC2NodeClass `role:` field on Karpenter v0.x. Retained for backwards compatibility; v1+ uses karpenter_node_role_name instead."
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "karpenter_interruption_queue_name" {
  description = "SQS interruption queue name — consumed by Karpenter's Helm chart `settings.interruptionQueue`."
  value       = aws_sqs_queue.karpenter_interruption.name
}

output "karpenter_interruption_queue_arn" {
  description = "SQS interruption queue ARN."
  value       = aws_sqs_queue.karpenter_interruption.arn
}
