# Helm provider — used only by helm_release.cilium (cilium.tf).
#
# The CNI now installs inside the eks bootstrap module, so the provider reads
# the cluster's endpoint + CA straight off the in-module aws_eks_cluster
# resource rather than from input variables. On a fresh stack these attributes
# are unknown at plan time, so Terraform defers provider initialization and the
# plan stays clean — base64decode of an unknown value is itself unknown, so no
# "unable to parse PEM" error (the failure mode that forced the argocd unit's
# mock-PEM dependency). The provider only actually connects at apply time, after
# the cluster exists.
#
# Authentication uses `exec` (aws eks get-token) rather than a static
# aws_eks_cluster_auth token: with wait=false the connection is short-lived, but
# exec re-mints a token per call and matches the argocd module's pattern.
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--region", var.aws_region]
    }
  }
}
