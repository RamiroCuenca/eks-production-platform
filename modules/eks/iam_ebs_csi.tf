# EBS CSI controller IRSA role.
#
# The controller is the only component that calls the EC2 API (volume create/
# attach/delete/snapshot); the node DaemonSet only does local mounts and needs
# no IAM — same single-workload scoping as the Cilium operator role. Unlike
# Cilium's ENI permissions, AWS publishes and maintains a managed policy for
# exactly this workload (AmazonEBSCSIDriverPolicy), so it is attached as-is
# rather than hand-rolled: the vendor-maintained permission set tracks driver
# releases, an inline copy would only drift.
#
# The role trusts the cluster OIDC provider for the ebs-csi-controller-sa
# ServiceAccount the managed addon creates in kube-system; the addon binds the
# role via service_account_role_arn (addons.tf).

locals {
  ebs_csi_namespace       = "kube-system"
  ebs_csi_service_account = "ebs-csi-controller-sa"

  # OIDC condition keys use the issuer host without the scheme; strip it
  # defensively (same note as the Cilium operator role).
  ebs_csi_oidc_url_no_scheme = replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")
}

resource "aws_iam_role" "ebs_csi_controller" {
  name = "${local.cluster_name}-ebs-csi-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.cluster.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.ebs_csi_oidc_url_no_scheme}:aud" = "sts.amazonaws.com"
          "${local.ebs_csi_oidc_url_no_scheme}:sub" = "system:serviceaccount:${local.ebs_csi_namespace}:${local.ebs_csi_service_account}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_controller" {
  role       = aws_iam_role.ebs_csi_controller.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
