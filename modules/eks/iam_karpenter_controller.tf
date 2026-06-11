# Karpenter controller IRSA role.
#
# Trusts the cluster OIDC provider for the configured ServiceAccount in
# the Karpenter namespace. The Helm chart in the gitops repo annotates the
# Karpenter ServiceAccount with the role ARN exposed in outputs.tf.
#
# Permissions follow the upstream Karpenter v1.x policy reference — scoped
# tightly to instances Karpenter itself created, to the cluster's
# instance-role-pass relationship, and to the cluster's own interruption
# queue. The policy intentionally avoids broad ec2:* permissions.

resource "aws_iam_role" "karpenter_controller" {
  name = "${local.cluster_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.cluster.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:${var.karpenter_namespace}:${var.karpenter_service_account}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "karpenter_controller" {
  name = "${local.cluster_name}-karpenter-controller"
  role = aws_iam_role.karpenter_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceAccessActions"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}::image/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}::snapshot/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:security-group/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:subnet/*",
        ]
      },
      {
        Sid    = "AllowScopedEC2LaunchTemplateAccessActions"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*"
        Condition = {
          StringEquals = { "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned" }
          StringLike   = { "aws:ResourceTag/karpenter.sh/nodepool" = "*" }
        }
      },
      {
        Sid    = "AllowScopedEC2InstanceActionsWithTags"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:fleet/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:volume/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:network-interface/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:spot-instances-request/*",
        ]
        Condition = {
          StringEquals = { "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}" = "owned" }
          StringLike   = { "aws:RequestTag/karpenter.sh/nodepool" = "*" }
        }
      },
      {
        Sid    = "AllowScopedResourceCreationTagging"
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:fleet/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:volume/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:network-interface/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:spot-instances-request/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "ec2:CreateAction" = [
              "RunInstances",
              "CreateFleet",
              "CreateLaunchTemplate",
            ]
          }
          StringLike = { "aws:RequestTag/karpenter.sh/nodepool" = "*" }
        }
      },
      {
        Sid      = "AllowScopedResourceTagging"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*"
        Condition = {
          StringEquals = { "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned" }
          StringLike   = { "aws:ResourceTag/karpenter.sh/nodepool" = "*" }
          StringEqualsIfExists = {
            "aws:RequestTag/eks:eks-cluster-name" = local.cluster_name
          }
          "ForAllValues:StringEquals" = {
            "aws:TagKeys" = [
              "eks:eks-cluster-name",
              "karpenter.sh/nodeclaim",
              "Name",
            ]
          }
        }
      },
      {
        Sid    = "AllowScopedDeletion"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate",
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*",
        ]
        Condition = {
          StringEquals = { "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned" }
          StringLike   = { "aws:ResourceTag/karpenter.sh/nodepool" = "*" }
        }
      },
      {
        Sid    = "AllowRegionalReadActions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" = var.aws_region }
        }
      },
      {
        Sid      = "AllowSSMReadActions"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::parameter/aws/service/*"
      },
      {
        Sid      = "AllowPricingReadActions"
        Effect   = "Allow"
        Action   = "pricing:GetProducts"
        Resource = "*"
      },
      {
        Sid    = "AllowInterruptionQueueActions"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        Sid      = "AllowPassingInstanceRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node.arn
        Condition = {
          StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileCreationActions"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:RequestTag/topology.kubernetes.io/region"               = var.aws_region
          }
          StringLike = { "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*" }
        }
      },
      {
        Sid      = "AllowScopedInstanceProfileTagActions"
        Effect   = "Allow"
        Action   = "iam:TagInstanceProfile"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"               = var.aws_region
            "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}"  = "owned"
            "aws:RequestTag/topology.kubernetes.io/region"                = var.aws_region
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"  = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileActions"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"               = var.aws_region
          }
          StringLike = { "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*" }
        }
      },
      {
        Sid      = "AllowInstanceProfileReadActions"
        Effect   = "Allow"
        Action   = "iam:GetInstanceProfile"
        Resource = "*"
      },
      {
        Sid      = "AllowAPIServerEndpointDiscovery"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = aws_eks_cluster.this.arn
      },
    ]
  })
}
