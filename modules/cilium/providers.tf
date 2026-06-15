# Module-local provider configuration.
#
# Provider VERSION pinning lives centrally in root.hcl's generated versions.tf;
# provider CONFIGURATION lives here because only cluster-touching modules
# (this one and modules/argocd) connect to the API server. The aws provider is
# configured by root.hcl's generated provider.tf at instantiation.
#
# Cluster endpoint + CA arrive as input variables sourced from the eks module
# via the Terragrunt dependency block — NOT via `data "aws_eks_cluster"`, which
# would resolve at plan time and fail on a fresh stack where the cluster does
# not exist yet. Authentication uses `exec` (aws eks get-token) rather than a
# static aws_eks_cluster_auth token: the Cilium install waits for the agent
# DaemonSet to roll out across nodes that only become Ready *after* Cilium
# itself programs their datapath, so the apply can outlast a 15-minute static
# token. The exec plugin re-mints a token per API call.

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}
