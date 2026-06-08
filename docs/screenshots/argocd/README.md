# ArgoCD + Karpenter — deployment evidence

ArgoCD bootstrapped on `eks-platform-dev-ap-northeast-1` (Kubernetes `1.35`, `ap-northeast-1`, account `730269305302`); Karpenter delivered as the first GitOps workload from `eks-platform-gitops`. Captured 2026-06-08. The cluster was on `1.35` at capture; the in-repo `cluster_version` has since been bumped to `1.36` for the next apply.

## ArgoCD bootstrap

| File | What it proves |
|---|---|
| `01-ui-login.png` | ArgoCD UI reachable via `kubectl port-forward` — confirms the deliberate "ClusterIP + port-forward, no public LoadBalancer" exposure design. |
| `02-clusters-registered.png` | Settings → Clusters → cluster detail: name `eks-platform-dev-ap-northeast-1`, labels (`env=dev`, `region=ap-northeast-1`), and the full annotation block carrying `karpenter-controller-role-arn`, `karpenter-node-role-name`, `karpenter-interruption-queue`. Proves the per-cluster value injection design (cluster Secret + ApplicationSet cluster generator) is wired end-to-end. |
| `02b-applications-tile.png` | Applications tile view: `root`, `karpenter`, `karpenter-resources` all `Healthy` + `Synced`. The iconic ArgoCD overview shot. |
| `03-applications-tree.png` | Root Application tree: `root` → `karpenter` + `karpenter-resources`, auto-sync enabled, last sync against gitops `main`. Proves the App-of-Apps wiring and the two-ApplicationSet Karpenter delivery (controller wave 0, resources wave 1). |
| `04-applications-cli.png` | `kubectl get applications -n argocd` showing the same three apps `Synced` + `Healthy` from the CLI — proves the ArgoCD state surfaces correctly to operators outside the UI. |

## Karpenter via GitOps

| File | What it proves |
|---|---|
| `05-karpenter-resources.png` | `kubectl get nodepool,ec2nodeclass`: the default `EC2NodeClass` and two `NodePool`s (general-purpose arm64 + amd64 fallback) created by ArgoCD from the local Helm chart in `eks-platform-gitops/controllers/karpenter/`. |
| `06-karpenter-app-tree.png` | `karpenter` Application tree in ArgoCD — upstream chart `1.12.1`, all 17 sub-resources `Synced` + `Healthy`, pods running. |
| `06b-karpenter-app-tree.png` | Same tree, expanded view of the Karpenter controller `Deployment` → `ReplicaSet` → `Pod` chain. |
| `06c-karpenter-sa-irsa-annotation.png` | Karpenter `ServiceAccount` showing the `eks.amazonaws.com/role-arn` annotation pointing at `karpenter-controller` — the IRSA composition: cluster Secret annotation → Helm values → ServiceAccount annotation → STS AssumeRoleWithWebIdentity. |
| `07-iam-irsa-trust.png` | IAM → `eks-platform-dev-ap-northeast-1-karpenter-controller` → Trust relationships: federated trust to the cluster OIDC provider with `sub = system:serviceaccount:karpenter:karpenter` and `aud = sts.amazonaws.com`. Closes the IRSA chain end-to-end. |

## Scale-up smoke test (closes the Phase 3 deferred item)

| File | What it proves |
|---|---|
| `08-scale-up-nodes-before.png` | `kubectl get nodes` before `kubectl scale deployment inflate --replicas=N`: only the 2 system MNG nodes (`m7g.large`, `ap-northeast-1c`). |
| `08b-scale-up-nodes-after.png` | `kubectl get nodes` after scale-up: 2 system MNG + 2 Karpenter-provisioned `c7g` spot nodes — Karpenter saw the pending pods and provisioned in seconds. |
| `09-karpenter-node-detail.png` | `kubectl describe node` of a Karpenter-provisioned node: `karpenter.sh/nodepool=general-purpose`, `karpenter.sh/capacity-type=spot`, `kubernetes.io/arch=arm64`, `node.kubernetes.io/instance-type=c7g.xlarge`. Proves the NodePool defaults (arm64-first, spot-first, general-purpose) are honored. |
| `09b-pods-across-nodes.png` | k9s pod view across namespaces: `argocd` + `karpenter` + `aws-node` (DaemonSet) pods on the system nodes; `inflate-*` pods distributed across the Karpenter-provisioned nodes. Proves the system-tier toleration design — system pods stay on the dedicated tier, application pods land on the burstable Karpenter fleet. |
| `10-ec2-spot-instance.png` | EC2 console filtered by `karpenter.sh/discovery=eks-platform-dev-ap-northeast-1`: the 2 Karpenter-launched instances, both `Running`, with the cluster discovery tag — closes the loop from `kubectl` to actual EC2 resources. |
| `10b-ec2-mixed-fleet.png` | EC2 console, unfiltered: full 4-instance fleet — 2 `m7g.large` system nodes in `ap-northeast-1c` (managed node group) + 2 Karpenter `c7g` spot nodes in `ap-northeast-1a`. The two pools coexist by design. |
| `11-karpenter-logs.png` | Karpenter controller logs: `launched nodeclaim`, `registered nodeclaim`, `initialized nodeclaim`, instance type selection, and the matching spot bid against the AWS EC2 spot pool — the provisioning decision trail. |
| `12-consolidation.png` | Karpenter consolidation event in the controller logs: idle replicas removed, surviving pods rescheduled onto a smaller node set. Proves the bin-packing claim — Karpenter actively right-sizes the fleet, not just provisions on demand. |
| `13-ec2-terminated.png` | EC2 console after `kubectl scale deployment inflate --replicas=0` + consolidation: Karpenter nodes `Terminated`, system MNG nodes untouched. Closes the smoke test with a clean steady state. |
