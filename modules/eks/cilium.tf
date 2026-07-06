# Cilium — the sole CNI, installed as a bootstrap primitive between the control
# plane and the managed node group.
#
# A cluster cannot run a single pod (not even CoreDNS, let alone ArgoCD) until a
# CNI exists, so the CNI installs imperatively here alongside the cluster itself,
# BEFORE any node joins. The CiliumNetworkPolicies that ride on top live in the
# gitops repo and are reconciled by ArgoCD — Terraform owns the datapath, GitOps
# owns the policy. See the journal "Cilium install boundary".
#
# Mode: full replacement of the AWS VPC CNI and kube-proxy.
#   - ENI IPAM             -> pods get routable VPC IPs (native routing, no overlay)
#   - kubeProxyReplacement -> eBPF service load-balancing, kube-proxy removed
#   - Hubble               -> flow observability (relay + UI, port-forward only)
#
# Bootstrap sequence: this release is created when the cluster has ZERO nodes
# (the managed node group depends_on it). The chart's manifests are applied and
# the release returns immediately (wait=false). The managed node group is then
# created; as each node joins it registers NotReady, the Cilium agent DaemonSet
# (tolerates everything) schedules onto it, the operator allocates an ENI, the
# datapath is programmed, and the node flips Ready — at which point the managed
# node group reaches ACTIVE. There is no aws-node/kube-proxy to delete and no
# swap; Cilium owns the datapath from the first node.

locals {
  # With kube-proxy removed there is no in-cluster proxy to back the
  # kubernetes.default Service, so Cilium is given the API server directly.
  api_server_host = replace(aws_eks_cluster.this.endpoint, "https://", "")

  # The system tier carries node-tier=system:NoSchedule. Platform components that
  # run as Deployments pin to it via affinity (system_affinity below) so they
  # don't ride ephemeral Karpenter nodes. Hubble relay/UI tolerate exactly the
  # system taint — they only ever need to land on Ready system nodes. The agent
  # and operator tolerate EVERYTHING (their own blocks below): they are on the
  # critical bootstrap path and must schedule onto still-NotReady system nodes
  # (which also carry node.kubernetes.io/not-ready:NoSchedule) to network them.
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

    # Masquerade stays off. In ENI IPAM mode the chart defaults
    # enable-ipv4-masquerade to false: pods get native, routable VPC IPs and
    # reach the internet through the subnet's NAT gateway (which SNATs), so
    # node-level masquerade is redundant — and it keeps pod source IPs intact
    # end-to-end, which is the point of ENI mode. Note bpf.masquerade must NOT
    # be set here: enabling eBPF masquerade while ipv4 masquerade is off is a
    # contradiction the agent rejects at startup ("BPF masquerade requires
    # --enable-ipv4-masquerade=true"), which crashloops the CNI.

    # ---------- Bottlerocket ----------
    # Bottlerocket mounts cgroup v2 at /sys/fs/cgroup itself; Cilium's
    # auto-mount would collide, so point it at the existing mount instead.
    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }

    # ---------- agent (DaemonSet, every node) ----------
    tolerations = [{ operator = "Exists" }]

    # ---------- metrics ----------
    # Exporters only — agent metrics on :9962 (a named `prometheus` container
    # port on the DaemonSet). The scrape configs (PodMonitors/ServiceMonitor)
    # deliberately live in the gitops observability chart: this release
    # applies at bootstrap on a zero-node cluster, before ArgoCD installs the
    # monitoring CRDs, so the chart's own serviceMonitor options would fail
    # every fresh build with "no matches for kind ServiceMonitor".
    prometheus = {
      enabled = true
    }

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
      replicas = var.cilium_operator_replicas

      # Operator metrics on :9963 — ENI/IPAM allocation health, which is
      # exactly the subsystem that broke twice during bootstrap hardening
      # (region resolution, DescribeRouteTables). Scraped from gitops like
      # the agent metrics above.
      prometheus = {
        enabled = true
      }
      # Tolerate everything (the chart default), NOT just the system taint. The
      # operator must allocate ENIs before any node can reach Ready, so at
      # bootstrap it has to land on a system node while it is still NotReady —
      # i.e. while it carries node.kubernetes.io/not-ready:NoSchedule (which the
      # default-tolerations admission does not cover for NoSchedule). The
      # affinity below — not the toleration — keeps it on the system tier and
      # off Karpenter nodes.
      tolerations = [{ operator = "Exists" }]
      affinity    = local.system_affinity

      # ENI IPAM mode: the operator's AWS SDK needs a region to build the EC2
      # API endpoint. The chart ships AWS_DEFAULT_REGION empty and relies on the
      # SDK auto-detecting the region from IMDS — which does not resolve for the
      # hostNetwork operator here, leaving the region blank. The ENI allocator
      # then fails its first EC2 call ("Failed initial EC2 API limits update")
      # and crashloops, blocking every node from getting ENIs/IPs. Set the
      # region explicitly; AWS_REGION takes SDK precedence over AWS_DEFAULT_REGION.
      extraEnv = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
      ]
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
      # Flow metrics on :9965; the chart also creates a headless
      # `hubble-metrics` Service in kube-system that the gitops
      # ServiceMonitor targets. Set chosen for the zero-trust story:
      # `drop` evidences default-deny enforcement, `dns` rides the DNS-proxy
      # visibility the FQDN policies depend on, the rest baseline the
      # traffic shape. httpV2 (L7) deliberately omitted — it needs
      # per-namespace visibility annotations plus an Envoy hop, and the
      # app's own RED metrics already cover L7.
      metrics = {
        enabled = [
          "dns",
          "drop",
          "tcp",
          "flow",
          "port-distribution",
          "icmp",
        ]
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

  # wait = false is MANDATORY here, and is the change that makes the whole
  # bootstrap work. This release is created while the cluster has ZERO nodes
  # (the node group depends_on it), so the operator Deployment is unschedulable
  # at install time — wait=true would block on a Ready operator that cannot
  # exist yet and hang the apply until timeout. With wait=false the chart's
  # manifests are applied and the release returns; the managed node group's own
  # ACTIVE gate (it won't converge until Cilium programs the nodes) is the real,
  # correct wait for Cilium being healthy.
  wait    = false
  timeout = 600

  values = [yamlencode(local.cilium_values)]

  # The cluster must exist (endpoint/CA for the provider, OIDC provider for the
  # operator's IRSA trust) before the chart is applied. The operator role is
  # referenced in values above, so its dependency is already implicit.
  depends_on = [
    aws_eks_cluster.this,
    aws_iam_openid_connect_provider.cluster,
  ]
}
