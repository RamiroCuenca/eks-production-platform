# Module-local provider configuration.
#
# Provider VERSION pinning lives centrally in root.hcl's generated versions.tf
# (Terraform requires `required_providers` to appear exactly once per module).
# Provider CONFIGURATION lives here because only this module connects to the
# cluster — every other module would fail at provider init time if these
# blocks were generated globally.
#
# Cluster endpoint + CA arrive as input variables sourced from the eks module
# via the Terragrunt dependency block — NOT via `data "aws_eks_cluster"`. The
# data source would resolve at plan time and hit AWS directly, failing on a
# fresh stack where the EKS cluster has not yet been applied. Threading these
# values through the dependency means Terragrunt's mock_outputs cover plan-all
# and the real outputs flow in once eks is applied.
#
# Authentication uses `exec` over a static token from `aws_eks_cluster_auth`
# because the data-source token has a fixed 15-minute lifetime. A long apply
# (Helm install of ArgoCD pulls ~10 images, waits for rollout) can outlast
# that window and start failing mid-apply with 401s. The exec plugin re-mints
# a token on demand for every API call.

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}

# helm provider v3 takes `kubernetes` and `exec` as attributes (`= { ... }`),
# not nested blocks — the v2 block form was removed in v3. (The kubernetes and
# kubectl providers below are unaffected and keep their block syntax.)
provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}

# kubectl provider: applies the root ArgoCD Application via server-side apply
# without validating the manifest's schema at plan time. The Application CRD
# is installed by the ArgoCD Helm chart in the same apply; hashicorp/kubernetes
# would fail the plan because the CRD doesn't exist yet. `load_config_file =
# false` prevents the provider from reading the local kubeconfig — the apply
# must be reproducible from any environment that has AWS credentials.
provider "kubectl" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}
