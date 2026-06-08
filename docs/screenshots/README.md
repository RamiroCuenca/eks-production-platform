# Deployment evidence

Screenshots captured from real AWS deployments of each module. Each subdirectory
corresponds to one module under `modules/` and contains a `README.md` with a
one-line caption per image — what the screenshot proves about the design.

| Module | Captured |
|---|---|
| [network/](network/) | VPC, subnets, NAT gateways, flow logs |
| [eks/](eks/) | Cluster overview, encryption, logging, networking, access entries, compute, OIDC provider, Karpenter IAM roles |
| [argocd/](argocd/) | ArgoCD bootstrap + Karpenter GitOps delivery, IRSA wiring, scale-up smoke test, consolidation |
