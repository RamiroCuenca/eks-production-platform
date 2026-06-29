# Deployment evidence

Screenshots captured from real AWS deployments of each module. Each subdirectory
corresponds to one module under `modules/` and contains a `README.md` with a
one-line caption per image, what the screenshot proves about the design.

| Module | Captured |
|---|---|
| [network/](network/) | VPC, subnets, NAT gateways, flow logs |
| [eks/](eks/) | Cluster overview, encryption, logging, networking, access entries, compute, OIDC provider, Karpenter IAM roles |
| [argocd/](argocd/) | ArgoCD bootstrap + Karpenter GitOps delivery, IRSA wiring, scale-up smoke test, consolidation |
| [ci/](ci/) | GitHub Actions OIDC federation: identity provider, per-env CI role trust policies, permissions boundary |
| [cilium/](cilium/) | Cilium CNI: agent status, ENI IPAM, kube-proxy replacement, CiliumNodes, Hubble UI, operator IRSA, default-deny network policy, Karpenter startup-taint gating |
| [secrets/](secrets/) | Secrets Manager + IRSA (ASCP): exact-ARN least-privilege policy, dedicated CMK encryption, CSI tmpfs file mount |
| [aurora/](aurora/) | Aurora PostgreSQL: Multi-AZ writer + reader, CMK encryption, RDS-managed credential rotation, intra-subnet isolation, force_ssl + live TLS connect |
| [elasticache/](elasticache/) | ElastiCache Redis: Multi-AZ replication group, at-rest + in-transit encryption, AUTH, intra-subnet isolation, live TLS+AUTH connect |
