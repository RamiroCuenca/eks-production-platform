# EKS module — deployment evidence

EKS cluster `eks-platform-dev-ap-northeast-1`, Kubernetes `1.35`, `ap-northeast-1`, account `730269305302`. Captured 2026-05-14.

| File | What it proves |
|---|---|
| `cluster-overview.png` | Cluster `Active`, Kubernetes `1.35`, support period until `2027-03-27`, platform version `eks.11`, OIDC issuer URL, cluster IAM role ARN, EKS Auto Mode `Disabled` — confirms the cluster is the deliberate "managed control plane + Karpenter" design, not Auto Mode. |
| `cluster-encryption.png` | EKS Overview (scrolled): **Envelope encryption** with a customer-managed KMS key (`129e8633-37d3-4352-94b1-98b4691c6732`) — proves per-cluster CMK for K8s secrets at rest, the one-way decision documented in the journal. |
| `cluster-logging.png` | EKS Observability tab → Control plane logs: all 5 log types (`API server`, `Audit`, `Authenticator`, `Controller manager`, `Scheduler`) wired to CloudWatch. |
| `cluster-networking.png` | EKS Networking tab: endpoint mode `Public and private`, public access source allowlist `0.0.0.0/0` for dev (prod is restricted via `api_public_access_cidrs`). |
| `cluster-access-entries.png` | EKS Access tab: **Authentication mode = `EKS API`** (no aws-auth ConfigMap fallback) and 4 access entries — the operator user with `AmazonEKSClusterAdminPolicy`, the Karpenter node role (`EC2 Linux`, `system:nodes`), the auto-created system-MNG node entry, and the EKS service-linked role. Proves the cluster runs entirely on access entries, not the legacy `aws-auth` pattern. |
| `cluster-compute-node-groups.png` | EKS Compute tab: `system` managed node group, desired size `2`, AMI release version `1.60.0-c1f9ba0c` (Bottlerocket arm64), `Active`. |
| `kubectl-get-nodes.png` | `kubectl get nodes -o wide`: 2 Bottlerocket OS `1.60.0 (aws-k8s-1.35)` nodes `Ready`, kernel `6.12.79`, containerd `2.1.6+bottlerocket`, no external IPs (private subnets only). |
| `cloudwatch-eks-log-group.png` | `/aws/eks/<cluster>/cluster` log group: retention `1 month`, standard log class — matches the 30d retention design. |
| `cloudwatch-eks-log-streams.png` | 12 log streams across all 5 control-plane components (`kube-apiserver`, `kube-apiserver-audit`, `authenticator`, `kube-controller-manager`, `kube-scheduler`, `cloud-controller-manager`) with recent timestamps — proves control-plane logging is producing data, not just configured. |
| `iam-oidc-provider.png` | IAM → Identity providers: cluster OIDC provider with issuer `oidc.eks.ap-northeast-1.amazonaws.com/id/...`, audience `sts.amazonaws.com` — the IRSA foundation. |
| `iam-karpenter-roles-list.png` | IAM Roles filtered: both Karpenter roles side by side — `karpenter-controller` (Trusted entity: Identity Provider, i.e. IRSA) vs `karpenter-node` (Trusted entity: AWS Service `ec2`). Visually proves the split-role design. |
| `iam-karpenter-controller-role.png` | Karpenter controller role → Trust relationships: federated trust resolves to the cluster OIDC provider with `sub = system:serviceaccount:karpenter:karpenter` and `aud = sts.amazonaws.com`. Proves IRSA wiring is correct before Phase 5 deploys the actual controller. |
| `iam-karpenter-node-role.png` | Karpenter node role: 4 AWS-managed policies attached (`AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonSSMManagedInstanceCore`), instance profile ARN visible — the role Karpenter will hand to provisioned EC2 nodes. |
