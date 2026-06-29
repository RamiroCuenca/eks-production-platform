# Cilium CNI — deployment evidence

Cilium `1.19.4` installed as the sole CNI on `eks-platform-dev-ap-northeast-1` (Kubernetes `1.36`, `ap-northeast-1`, account `730269305302`) in ENI IPAM mode with eBPF kube-proxy replacement and Hubble observability. Captured 2026-06-24 (network-policy enforcement flows 2026-06-28).

## CNI installation proof

| File | What it proves |
|---|---|
| `01-agent-status.png` | `cilium status` on the agent DaemonSet: `CNI Chaining: Disabled` (full replacement, not chaining), `Routing: Network: Native Host: BPF` (eBPF kube-proxy replacement active), `IPAM: IPv4: 8/16 allocated` (ENI IP pool populated by the operator), `Cluster health: 2/2 reachable`. Closes the loop on the three core architecture decisions: ENI mode, kube-proxy replacement, no chaining. |
| `02-no-vpc-cni.png` | k9s all-namespaces pod view: no `aws-node` DaemonSet, no `kube-proxy` DaemonSet anywhere in the cluster. Proves Cilium replaced VPC CNI and kube-proxy entirely — `bootstrap_self_managed_addons = false` worked as designed, so neither addon was ever installed. |
| `03-pods-vpc-ips.png` | `kubectl get pods -A -o wide`: every pod IP (`10.0.x.x`) is a native VPC address drawn from the ENI secondary IP pool — not an overlay. Confirms ENI IPAM assigns routable VPC IPs directly to pods with no encapsulation. |
| `04-ciliumnodes.png` | `kubectl get ciliumnodes -o wide`: the `CiliumNode` CRs created by the Cilium operator for all 4 nodes (2 system MNG + 2 Karpenter-provisioned). `CILIUMINTERNALIP` (secondary ENI IP allocated to Cilium) differs from `INTERNALIP` (node primary IP) — confirms the operator's IRSA role successfully called the EC2 ENI allocation APIs and populated each node's IP pool. |

## Operator IRSA

| File | What it proves |
|---|---|
| `07-iam-cilium-operator-trust.png` | IAM → `eks-platform-dev-ap-northeast-1-cilium-operator` → Trust relationships: federated trust to the cluster OIDC provider scoped to `system:serviceaccount:kube-system:cilium-operator`. The EC2 ENI permissions (DescribeNetworkInterfaces, CreateNetworkInterface, AssignPrivateIpAddresses, etc.) land on the operator pod via STS, not on the node instance role — consistent with the project-wide IRSA-over-node-IAM default. |

## Hubble observability

| File | What it proves |
|---|---|
| `05-hubble-ui.png` | Hubble UI at `localhost:12000` (port-forwarded from `svc/hubble-ui`), `kube-system` namespace selected: flow graph showing `hubble-ui → hubble-relay` and `hubble-ui → kube-apiserver` with all flows `forwarded`, 18.4 flows/s across 6/7 nodes. Proves the Hubble relay layer is operational and the UI can surface real-time L3/L4 flow data. |

## Network policy enforcement (default-deny)

The `network-policies` ArgoCD app syncs a cluster-wide default-deny `CiliumNetworkPolicy`. These two flows prove the deny-by-default posture and an explicit allow override, observed live through Hubble.

| File | What it proves |
|---|---|
| `08-hubble-deny-flows.png` | Top: `kubectl -n demo exec a -- ping -c2 b` returns `100% packet loss` (exit 1). Bottom: `hubble observe -n demo --verdict DROPPED` shows `demo/a <> demo/b ... Policy denied DROPPED (ICMPv4 EchoRequest)`. With no policy permitting it, pod-to-pod traffic is dropped under the cluster-wide default-deny; the `Policy denied` verdict attributes the drop to policy enforcement — not a routing or DNS failure. |
| `09-hubble-allow-flows.png` | After applying a namespace-scoped `allow-demo-intra` CiliumNetworkPolicy (`ingress` from / `egress` to `endpointSelector: {}`), the same `a → b` ping returns `0% packet loss`, and `hubble observe -n demo --verdict FORWARDED` shows `to-endpoint FORWARDED` for both the ICMP EchoRequest and EchoReply. Confirms enforcement is allowlist-based — traffic flows only once an explicit policy permits it — and that the policy change takes effect immediately, with no pod restart. |

## Node bootstrap — CNI readiness gating

| File | What it proves |
|---|---|
| `10-karpenter-startup-taint.png` | A 1s poll of the newest Karpenter node's `.spec.taints` as it joins the cluster: the freshly-provisioned node (`ip-10-0-63-8`) comes up carrying `node.cilium.io/agent-not-ready` — a `startupTaints` entry on the Karpenter NodePool (`controllers/karpenter/templates/nodepool-general-purpose*.yaml`) — alongside the standard `node.kubernetes.io/not-ready` lifecycle taints. ~27s later Cilium's agent goes Ready and removes its taint, and the node becomes schedulable. Proves the Karpenter↔Cilium bootstrap ordering that keeps pods off a node until its CNI is up, avoiding the schedule-before-network race. |

## AWS-layer proof

| File | What it proves |
|---|---|
| `06-eni-console.png` | EC2 console → Network Interfaces filtered by VPC: 12 interfaces, several with `Description` containing `Cilium-CNI` — the ENIs Cilium created and attaches secondary IPs from. Closes the loop from `CiliumNode` CRs to actual AWS resources, confirming the operator's IAM permissions are effective end-to-end. |
