# Managed EKS addons.
#
# Cluster-critical components are pinned as managed addons so EKS handles
# the version-skew matrix against the control plane and applies updates in
# a controlled way. Just as importantly, this is the ONLY supported surface
# for injecting tolerations into CoreDNS — without a toleration that
# matches the system MNG's `node-tier=system:NoSchedule` taint, coredns
# pods stay Pending on a freshly bootstrapped cluster (no untainted nodes
# exist until Karpenter is in place, which can't happen until ArgoCD is
# in place, which can't happen until DNS works — a classic Day-1 ordering
# trap).
#
# vpc-cni and kube-proxy ship as DaemonSets that tolerate everything by
# default; managing them here is purely so version pinning lives in IaC.

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"

  configuration_values = jsonencode({
    tolerations = [
      {
        key      = "node-tier"
        operator = "Equal"
        value    = "system"
        effect   = "NoSchedule"
      },
    ]
  })

  # Take ownership of the cluster-default coredns deployment EKS creates at
  # cluster bootstrap. Without OVERWRITE, the first apply errors out with
  # "addon already exists" because EKS pre-installed an unmanaged copy.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # CoreDNS needs at least one node to schedule on; the system MNG must
  # exist before the addon's pods can start.
  depends_on = [aws_eks_node_group.system]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.system]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.system]
}
