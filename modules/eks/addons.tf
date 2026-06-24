# Managed EKS addons.
#
# Only CoreDNS. The cluster is created with bootstrap_self_managed_addons = false
# (main.tf), so EKS installs NO default vpc-cni / kube-proxy / coredns. Cilium
# replaces vpc-cni AND kube-proxy (eBPF kube-proxy replacement — see cilium.tf),
# so neither is managed here. CoreDNS has no Cilium equivalent and is installed
# as a managed addon for two reasons:
#
#   1. Versioning — EKS handles the CoreDNS<->control-plane version-skew matrix.
#   2. Tolerations — the managed addon's `configuration_values` is the only
#      supported surface for injecting the system-tier toleration declaratively.
#      The default CoreDNS Deployment tolerates only CriticalAddonsOnly /
#      control-plane taints, so on a cluster whose only nodes carry
#      node-tier=system:NoSchedule it would sit Pending.
#
# CoreDNS installs AFTER the system node group (depends_on below), which itself
# installs after Cilium — so by the time CoreDNS schedules, a CNI exists and the
# pods come up directly on a Cilium ENI IP. resolve_conflicts OVERWRITE is
# harmless here (no pre-existing CoreDNS with bootstrap=false) and keeps the
# addon idempotent across re-applies.

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
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

  # CoreDNS needs at least one Ready node to schedule on; the system node group
  # must exist (and therefore Cilium must have networked it) first.
  depends_on = [aws_eks_node_group.system]
}
