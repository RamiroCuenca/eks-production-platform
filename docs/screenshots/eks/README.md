# EKS module — deployment evidence

_Pending — will be populated after the EKS cluster is captured during the same `dev/ap-northeast-1` build session._

Planned shots:

| File (planned) | What it should prove |
|---|---|
| `cluster-overview.png` | Cluster `Active`, K8s version, control-plane logging enabled for all 5 log types, envelope encryption with customer-managed CMK, endpoint access config. |
| `cluster-compute-node-groups.png` | System managed node group with Bottlerocket arm64 AMI, on-demand capacity, taint. |
| `kubectl-get-nodes.png` | Terminal output: 2 Bottlerocket arm64 nodes `Ready`, kernel/OS image visible. |
| `cloudwatch-eks-log-group.png` | `/aws/eks/<cluster>/cluster` log group, 30-day retention, log streams flowing for each of the 5 control-plane log types. |
| `iam-oidc-provider.png` | IRSA OIDC provider registered in IAM with the cluster's OIDC issuer URL. |
| `iam-karpenter-controller-role.png` _(optional)_ | Karpenter controller IRSA role trust policy resolves to the OIDC provider for `system:serviceaccount:karpenter:karpenter`. |
