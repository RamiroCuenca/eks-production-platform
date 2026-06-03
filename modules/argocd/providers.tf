# Module-local provider configuration.
#
# Provider VERSION pinning lives centrally in root.hcl's generated versions.tf
# (Terraform requires `required_providers` to appear exactly once per module).
# Provider CONFIGURATION lives here because only this module connects to the
# cluster — every other module would fail at provider init time if these
# blocks were generated globally.
#
# Authenticate the cluster providers against the EKS API.
#
# Using `exec` over a static token from `aws_eks_cluster_auth` because the
# data-source token has a fixed 15-minute lifetime. A long apply (Helm
# install of ArgoCD pulls ~10 images, waits for rollout) can outlast that
# window and start failing mid-apply with 401s. The exec plugin re-mints a
# token on demand for every API call.

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}
