# Deployment evidence

Screenshots captured from real AWS deployments. Each subdirectory corresponds to
one module under `modules/` or one runtime concern of the composed platform, and
contains a `README.md` with a one-line caption per image, what the screenshot
proves about the design.

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
| [ecr/](ecr/) | ECR registry + app CI identity: immutable SHA tags, multi-arch manifests, scan-on-push, main-ref-only OIDC trust, publish skipped on PRs, CloudTrail role assumptions, auto-merged GitOps promotion PR |
| [app/](app/) | Application runtime: GitOps-delivered workload live against Aurora + Redis, wave-ordered db-init, CSI secret mounts on a distroless image, FQDN-pinned data-tier egress, ZAP baseline |
| [observability/](observability/) | kube-prometheus-stack + Loki/Alloy: system-tier placement, scrape path through default-deny, SLO/Hubble/fleet dashboards, live logs, alert firing end to end |
| [loadtest/](loadtest/) | k6 load tests: HPA scale-out with Karpenter just-in-time capacity, KEDA scale-from-zero on queue depth, thresholds mirroring the Prometheus alert rules |
