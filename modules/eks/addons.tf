# Managed EKS addons.
#
# CoreDNS and the EBS CSI driver. The cluster is created with
# bootstrap_self_managed_addons = false (main.tf), so EKS installs NO default
# vpc-cni / kube-proxy / coredns. Cilium replaces vpc-cni AND kube-proxy (eBPF
# kube-proxy replacement — see cilium.tf), so neither is managed here. CoreDNS
# has no Cilium equivalent and is installed as a managed addon for two reasons:
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

# EBS CSI driver — dynamic PersistentVolume provisioning. In-tree EBS support
# left upstream Kubernetes in 1.27, so without this driver a PVC never binds;
# its first consumers are the observability stores (Prometheus TSDB, Loki
# chunks) delivered through the gitops repo. Managed addon for the same two
# reasons as CoreDNS: EKS owns the version-compat matrix, and
# configuration_values is the supported surface for scheduling config. The
# controller (the only AWS-API caller — see iam_ebs_csi.tf) is pinned to the
# system tier; the node DaemonSet tolerates all taints by default and needs no
# placement help. The gp3 StorageClass that consumes the driver lives in the
# gitops repo with the workloads that reference it.

resource "aws_eks_addon" "ebs_csi" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = var.ebs_csi_addon_version != "" ? var.ebs_csi_addon_version : null

  # The addon creates ebs-csi-controller-sa and annotates it with this role.
  service_account_role_arn = aws_iam_role.ebs_csi_controller.arn

  configuration_values = jsonencode({
    controller = {
      tolerations = [
        {
          key      = "node-tier"
          operator = "Equal"
          value    = "system"
          effect   = "NoSchedule"
        },
      ]
      # Keep the controller off ephemeral Karpenter capacity — volume
      # attach/detach must not stall because consolidation moved the
      # controller. Same DoesNotExist pattern as ArgoCD and Karpenter itself.
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [{
              matchExpressions = [{
                key      = "karpenter.sh/nodepool"
                operator = "DoesNotExist"
              }]
            }]
          }
        }
      }
    }
  })

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.system]
}

# metrics-server — serves the resource-metrics API (metrics.k8s.io) behind
# `kubectl top` and, critically, every Resource-type HPA: the go-demo server
# scales on CPU utilization, and utilization is computed from this API.
# Nothing else on the cluster provides it — kube-prometheus-stack feeds
# Grafana/alerting (no prometheus-adapter installed), and KEDA registers only
# the *external* metrics API for its scalers. Without this addon a CPU HPA
# reads <unknown> forever and never scales.
#
# Managed addon for the same reasons as CoreDNS, and pinned to the system tier
# like the EBS CSI controller: an HPA evaluating against a metrics backend
# that restarts whenever Karpenter consolidates a node would stall exactly
# when scaling decisions matter most — mid-load.

resource "aws_eks_addon" "metrics_server" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "metrics-server"
  addon_version = var.metrics_server_addon_version != "" ? var.metrics_server_addon_version : null

  configuration_values = jsonencode({
    tolerations = [
      {
        key      = "node-tier"
        operator = "Equal"
        value    = "system"
        effect   = "NoSchedule"
      },
    ]
    affinity = {
      nodeAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [{
              key      = "karpenter.sh/nodepool"
              operator = "DoesNotExist"
            }]
          }]
        }
      }
    }
  })

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.system]
}
