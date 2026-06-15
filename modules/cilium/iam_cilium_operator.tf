# Cilium operator IRSA role.
#
# In ENI IPAM mode the Cilium OPERATOR is the only component that talks to the
# EC2 API — it allocates ENIs and secondary IPs to nodes and tags them. The
# agent (a hostNetwork DaemonSet) does no AWS calls, so it gets no IAM. This
# keeps EC2 networking permissions on the single workload that needs them,
# consistent with the project's IRSA-over-node-IAM default — the opposite of
# putting the ENI permissions on the node instance role, which would hand every
# pod on the node the ability to manipulate network interfaces.
#
# The role trusts the cluster OIDC provider for the cilium-operator
# ServiceAccount in kube-system; the Helm release annotates that SA with the
# role ARN below.

locals {
  operator_namespace       = "kube-system"
  operator_service_account = "cilium-operator"

  oidc_url_no_scheme = replace(var.oidc_provider_url, "https://", "")
}

resource "aws_iam_role" "cilium_operator" {
  name = "${var.name_prefix}-cilium-operator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url_no_scheme}:aud" = "sts.amazonaws.com"
          "${local.oidc_url_no_scheme}:sub" = "system:serviceaccount:${local.operator_namespace}:${local.operator_service_account}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "cilium_operator" {
  name = "${var.name_prefix}-cilium-operator"
  role = aws_iam_role.cilium_operator.id

  # Cilium's documented ENI-mode permission set. The mutating ENI actions and
  # the Describe* reads cannot be resource-scoped to specific ARNs — ENIs are
  # created dynamically and the describes are account/region-wide by design
  # (the AWS-managed AmazonEKS_CNI_Policy the VPC CNI used is written the same
  # way). CreateTags is constrained to the network-interface resource type.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CiliumENIReadActions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
        ]
        Resource = "*"
      },
      {
        Sid    = "CiliumENILifecycleActions"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses",
        ]
        Resource = "*"
      },
      {
        Sid      = "CiliumENITagging"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = "arn:aws:ec2:*:*:network-interface/*"
      },
    ]
  })
}
