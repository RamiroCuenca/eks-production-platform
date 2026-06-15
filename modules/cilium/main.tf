# Cilium — the sole CNI.
#
# This module is the second (and last) place Terraform installs in-cluster
# state, alongside modules/argocd. The boundary is deliberate: the CNI is a
# bootstrap primitive — a cluster cannot run a single pod, including ArgoCD,
# until a CNI exists — so it installs imperatively like the cluster and the
# GitOps controller themselves. The CiliumNetworkPolicies that ride on top live
# in the gitops repo and are reconciled by ArgoCD. See the journal entry
# "Cilium install boundary".
#
# Mode: full replacement of the AWS VPC CNI and kube-proxy.
#   - ENI IPAM        → pods get routable VPC IPs (native routing, no overlay)
#   - kubeProxyReplacement → eBPF service load-balancing, kube-proxy removed
#   - Hubble          → flow observability (relay + UI, port-forward only)
#
# Bootstrap sequence inside this module: the cluster + system MNG already exist
# (Terragrunt dependency on eks) with nodes NotReady (no CNI yet). The Cilium
# agent DaemonSet is hostNetwork and tolerates the NotReady/system-taint state,
# so it schedules onto those nodes, programs the datapath, and the nodes go
# Ready — at which point CoreDNS (coredns.tf, depends_on this release) can
# schedule.

locals {
  # With kube-proxy removed there is no in-cluster proxy to back the
  # kubernetes.default Service, so Cilium is given the API server directly.
  api_server_host = replace(var.cluster_endpoint, "https://", "")

  # The system MNG carries node-tier=system:NoSchedule. Every platform
  # component that runs as a Deployment (operator, Hubble relay/UI) must
  # tolerate it AND pin to the system tier — at bootstrap the only nodes that
  # exist are the tainted system nodes, and these components should not ride
  # ephemeral spot Karpenter nodes afterwards. The agent DaemonSet is exempt:
  # the CNI must run on every node, so it tolerates everything unconditionally.
  system_toleration = {
    key      = "node-tier"
    operator = "Equal"
    value    = "system"
    effect   = "NoSchedule"
  }

  system_affinity = {
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

  cilium_values = {
    # ---------- datapath ----------
    kubeProxyReplacement = true
    k8sServiceHost       = local.api_server_host
    k8sServicePort       = 443

    ipam           = { mode = "eni" }
    eni            = { enabled = true }
    routingMode    = "native"
    endpointRoutes = { enabled = true }
    bpf            = { masquerade = true }

    # ---------- Bottlerocket ----------
    # Bottlerocket mounts cgroup v2 at /sys/fs/cgroup itself; Cilium's
    # auto-mount would collide, so point it at the existing mount instead.
    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }

    # ---------- agent (DaemonSet, every node) ----------
    tolerations = [{ operator = "Exists" }]

    # ---------- operator (ENI allocator, IRSA) ----------
    serviceAccounts = {
      operator = {
        name = local.operator_service_account
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.cilium_operator.arn
        }
      }
    }
    operator = {
      replicas    = var.cilium_operator_replicas
      tolerations = [local.system_toleration]
      affinity    = local.system_affinity
    }

    # ---------- Hubble ----------
    hubble = {
      enabled = true
      relay = {
        enabled     = true
        tolerations = [local.system_toleration]
        affinity    = local.system_affinity
      }
      ui = {
        enabled     = var.hubble_ui_enabled
        tolerations = [local.system_toleration]
        affinity    = local.system_affinity
      }
    }
  }
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"

  # Wait for the agent rollout: nodes only become Ready once Cilium programs
  # their datapath, so downstream resources (the CoreDNS addon, and the whole
  # argocd module that depends on this unit) must not proceed until the agent
  # DaemonSet is up. The agent pods are hostNetwork and do not themselves need
  # a working pod network to start, so this converges rather than deadlocks.
  wait    = true
  timeout = 600

  values = [yamlencode(local.cilium_values)]
}
