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

# The secrets module produces the workload IRSA role ARNs and the env-scoped
# secret names that the gitops charts need. They cross into the public
# gitops repo only through the ArgoCD cluster Secret this module writes — so
# argocd fans in on both eks and secrets (edge: eks -> secrets -> argocd).
dependency "secrets" {
  config_path = "../secrets"

  mock_outputs = {
    demo_app_secrets_role_arn = "arn:aws:iam::000000000000:role/mock-demo-app-secrets"
    demo_secret_name          = "eks-platform/dev/demo-app/credentials"
    go_demo_secrets_role_arn  = "arn:aws:iam::000000000000:role/mock-go-demo"
    go_demo_db_init_role_arn  = "arn:aws:iam::000000000000:role/mock-go-demo-db-init"
    go_demo_db_secret_name    = "eks-platform/dev/go-demo/db-credentials"
    go_demo_db_username       = "app_user"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

# Data-tier connection facts (endpoints, ports, dbname, the master-secret ARN)
# are apply-generated and Terraform-owned; they reach the go-demo chart as
# cluster-Secret annotations rather than hardcoded gitops values. Secret
# MATERIAL still travels only through the CSI mount.
dependency "aurora" {
  config_path = "../aurora"

  mock_outputs = {
    cluster_endpoint       = "mock.cluster-xyz.ap-northeast-1.rds.amazonaws.com"
    port                   = 5432
    database_name          = "appdb"
    master_user_secret_arn = "arn:aws:secretsmanager:ap-northeast-1:000000000000:secret:rds!cluster-MOCK-abcdef"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

dependency "elasticache" {
  config_path = "../elasticache"

  mock_outputs = {
    primary_endpoint       = "mock.xyz.apne1.cache.amazonaws.com"
    port                   = 6379
    connection_secret_name = "eks-platform/dev/redis/connection"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

# The registry URL embeds the account ID, so it also travels the annotation
# bridge; the app CI commit-back promotes only the image tag into gitops.
dependency "ecr" {
  config_path = "../ecr"

  mock_outputs = {
    repository_url = "000000000000.dkr.ecr.ap-northeast-1.amazonaws.com/eks-platform/demo-app"
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

  go_demo_secrets_role_arn = dependency.secrets.outputs.go_demo_secrets_role_arn
  go_demo_db_init_role_arn = dependency.secrets.outputs.go_demo_db_init_role_arn
  go_demo_db_secret_name   = dependency.secrets.outputs.go_demo_db_secret_name
  go_demo_db_username      = dependency.secrets.outputs.go_demo_db_username

  aurora_master_secret_arn = dependency.aurora.outputs.master_user_secret_arn
  aurora_writer_endpoint   = dependency.aurora.outputs.cluster_endpoint
  aurora_port              = dependency.aurora.outputs.port
  aurora_database_name     = dependency.aurora.outputs.database_name

  redis_primary_endpoint       = dependency.elasticache.outputs.primary_endpoint
  redis_port                   = dependency.elasticache.outputs.port
  redis_connection_secret_name = dependency.elasticache.outputs.connection_secret_name

  ecr_repository_url = dependency.ecr.outputs.repository_url

  gitops_repo_url = "https://github.com/RamiroCuenca/eks-platform-gitops.git"

  # Dev posture: single-replica everything. Prod will set ha_enabled = true.
  ha_enabled = false
}
