include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/argocd"
}

# EKS provides every per-cluster fact the ArgoCD cluster Secret needs to
# carry forward to the gitops-repo ApplicationSets.
dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name     = "eks-platform-dev-ap-northeast-1"
    cluster_endpoint = "https://mock.eks.amazonaws.com"
    # Base64-encoded throwaway x509 PEM. The hashicorp/kubernetes and
    # gavinbunney/kubectl providers eagerly parse the CA when the provider
    # block initializes (before any resource diff runs), so the mock must be
    # a real PEM block or the plan errors out with "unable to parse bytes as
    # PEM block". Never actually used to connect — the providers don't reach
    # the cluster during plan because the diff stays local to the Helm/kube
    # state. Replaced with the real CA at apply time via dependency outputs.
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJoVENDQVN1Z0F3SUJBZ0lRSVJpNnplUEw2bUtqT2lwbitkTnVhVEFLQmdncWhrak9QUVFEQWpBU01SQXcKRGdZRFZRUUtFd2RCWTIxbElFTnZNQjRYRFRFM01UQXlNREU1TkRNd05sb1hEVEU0TVRBeU1ERTVORE13TmxvdwpFakVRTUE0R0ExVUVDaE1IUVdOdFpTQkRiekJaTUJNR0J5cUdTTTQ5QWdFR0NDcUdTTTQ5QXdFSEEwSUFCRDBkCjdWTmhiV3ZaTFdQdWovUnRIRmp2dEpCRXdPa2hiTi9Cbm5FOHJuWlI4K3Nid25jL0toQ2szRmhucEhablF6N0IKNWFFVGJiSWdtdXZld2RqdlNCU2pZekJoTUE0R0ExVWREd0VCL3dRRUF3SUNwREFUQmdOVkhTVUVEREFLQmdncgpCZ0VGQlFjREFUQVBCZ05WSFJNQkFmOEVCVEFEQVFIL01Da0dBMVVkRVFRaU1DQ0NEbXh2WTJGc2FHOXpkRG8xCk5EVXpnZzR4TWpjdU1DNHdMakU2TlRRMU16QUtCZ2dxaGtqT1BRUURBZ05JQURCRkFpRUEyenBKRVBReXo2L2wKV2Y4NmFYNlBlcHNudFp2MkdZbEE1VXBhYmZUMkVaSUNJQ3BKNWgvaUkraTM0MWdCbUxpQUZRT3lURFQrL3dRYwo2TUY5K1l3MVl5MHQKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
    karpenter_controller_role_arn      = "arn:aws:iam::000000000000:role/mock-karpenter-controller"
    karpenter_node_role_name           = "mock-karpenter-node"
    karpenter_interruption_queue_name  = "mock-karpenter-interruption"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

# The secrets module produces the demo-app IRSA role ARN and the env-scoped
# secret name that the gitops demo chart needs. They cross into the public
# gitops repo only through the ArgoCD cluster Secret this module writes — so
# argocd fans in on both eks and secrets (edge: eks -> secrets -> argocd).
dependency "secrets" {
  config_path = "../secrets"

  mock_outputs = {
    demo_app_secrets_role_arn = "arn:aws:iam::000000000000:role/mock-demo-app-secrets"
    demo_secret_name          = "eks-platform/dev/demo-app/credentials"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

inputs = {
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  karpenter_controller_role_arn      = dependency.eks.outputs.karpenter_controller_role_arn
  karpenter_node_role_name           = dependency.eks.outputs.karpenter_node_role_name
  karpenter_interruption_queue_name  = dependency.eks.outputs.karpenter_interruption_queue_name

  demo_app_secrets_role_arn = dependency.secrets.outputs.demo_app_secrets_role_arn
  demo_secret_name          = dependency.secrets.outputs.demo_secret_name

  gitops_repo_url = "https://github.com/RamiroCuenca/eks-platform-gitops.git"

  # Dev posture: single-replica everything. Prod will set ha_enabled = true.
  ha_enabled = false
}
