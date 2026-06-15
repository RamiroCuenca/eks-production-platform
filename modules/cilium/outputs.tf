# Ordering handle. The argocd module takes a Terragrunt dependency on this
# unit purely to sequence after the CNI is healthy (a cluster cannot run
# ArgoCD without a working CNI). Exposing a value the dependent can reference
# makes the edge explicit rather than relying on apply-order luck.
output "cilium_ready" {
  description = "Resolves once the Cilium Helm release has rolled out and CoreDNS is installed — a signal the cluster network is ready for ArgoCD and workloads."
  value       = "${helm_release.cilium.name}:${aws_eks_addon.coredns.id}"
}

output "cilium_operator_role_arn" {
  description = "IAM role ARN bound to the Cilium operator ServiceAccount via IRSA (ENI IPAM permissions)."
  value       = aws_iam_role.cilium_operator.arn
}
