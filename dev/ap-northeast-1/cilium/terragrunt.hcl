include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/cilium"
}

# Cilium is the sole CNI and installs as a bootstrap primitive between the
# cluster and ArgoCD: it needs the cluster + OIDC provider to exist, and
# ArgoCD (next in the chain) needs a working CNI before its pods can run.
dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name     = "eks-platform-dev-ap-northeast-1"
    cluster_endpoint = "https://mock.eks.amazonaws.com"
    # Base64-encoded throwaway x509 PEM. The helm provider's kubernetes block
    # decodes the CA when the provider initializes (before any resource diff),
    # so the mock must be a real PEM or the plan errors with "unable to parse
    # bytes as PEM block". Never used to connect — replaced with the real CA at
    # apply time via dependency outputs.
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJoVENDQVN1Z0F3SUJBZ0lRSVJpNnplUEw2bUtqT2lwbitkTnVhVEFLQmdncWhrak9QUVFEQWpBU01SQXcKRGdZRFZRUUtFd2RCWTIxbElFTnZNQjRYRFRFM01UQXlNREU1TkRNd05sb1hEVEU0TVRBeU1ERTVORE13TmxvdwpFakVRTUE0R0ExVUVDaE1IUVdOdFpTQkRiekJaTUJNR0J5cUdTTTQ5QWdFR0NDcUdTTTQ5QXdFSEEwSUFCRDBkCjdWTmhiV3ZaTFdQdWovUnRIRmp2dEpCRXdPa2hiTi9Cbm5FOHJuWlI4K3Nid25jL0toQ2szRmhucEhablF6N0IKNWFFVGJiSWdtdXZld2RqdlNCU2pZekJoTUE0R0ExVWREd0VCL3dRRUF3SUNwREFUQmdOVkhTVUVEREFLQmdncgpCZ0VGQlFjREFUQVBCZ05WSFJNQkFmOEVCVEFEQVFIL01Da0dBMVVkRVFRaU1DQ0NEbXh2WTJGc2FHOXpkRG8xCk5EVXpnZzR4TWpjdU1DNHdMakU2TlRRMU16QUtCZ2dxaGtqT1BRUURBZ05JQURCRkFpRUEyenBKRVBReXo2L2wKV2Y4NmFYNlBlcHNudFp2MkdZbEE1VXBhYmZUMkVaSUNJQ3BKNWgvaUkraTM0MWdCbUxpQUZRT3lURFQrL3dRYwo2TUY5K1l3MVl5MHQKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
    oidc_provider_arn                  = "arn:aws:iam::000000000000:oidc-provider/oidc.eks.ap-northeast-1.amazonaws.com/id/MOCK"
    oidc_provider_url                  = "https://oidc.eks.ap-northeast-1.amazonaws.com/id/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

inputs = {
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  oidc_provider_arn                  = dependency.eks.outputs.oidc_provider_arn
  oidc_provider_url                  = dependency.eks.outputs.oidc_provider_url
}
