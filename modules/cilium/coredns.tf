# CoreDNS managed addon — relocated here from modules/eks.
#
# CoreDNS cannot reach ACTIVE until a CNI exists for its pods to get IPs.
# Because the cluster is created with bootstrap_self_managed_addons = false,
# EKS installs no default CoreDNS; we install it here, AFTER the Cilium release,
# so the bring-up order (cluster → CNI → DNS) is explicit in the dependency
# graph instead of deadlocking an eks-module apply that waits on a DNS addon
# the cluster has no networking for.
#
# The system MNG taint (node-tier=system:NoSchedule) means CoreDNS — like every
# other cluster-critical component — needs an explicit toleration or it stays
# Pending on a fresh cluster where no untainted nodes exist yet. This is the
# only supported surface for injecting that toleration into CoreDNS.

resource "aws_eks_addon" "coredns" {
  cluster_name  = var.cluster_name
  addon_name    = "coredns"
  addon_version = var.coredns_addon_version != "" ? var.coredns_addon_version : null

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

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # CoreDNS pods need a working CNI to get IPs and schedule — Cilium must be
  # rolled out (and the system nodes Ready) first.
  depends_on = [helm_release.cilium]
}
