# eks-production-platform
Production-grade EKS platform with GitOps, DevSecOps, and full observability on AWS using Terragrunt and ArgoCD.

---

## Why this project — and why these specific design choices

This platform is intentionally designed around the architectural concerns most relevant to Japan-headquartered tech companies (PayPay, Mercari, LINE, Woven, SmartHR, LayerX, et al). Every major decision is documented with its rationale, not just the implementation.

### Alignment with Japanese production environments

- **Multi-region in Asia-Pacific.** Topology spans `ap-northeast-1` (Tokyo) and `ap-northeast-2` (Seoul), mirroring real production patterns at Japan-based platforms — not the `us-east-1` default common in tutorial projects. Disaster-recovery validation is exercised in `dev` before being applied to `prod`.
- **Security-first defaults.** Envelope encryption with customer-managed KMS keys (with key rotation), IRSA with tightly scoped IAM policies (no `ec2:*` blanket permissions — every action is conditioned on cluster ownership tags), modern EKS access entries (replacing the deprecated `aws-auth` ConfigMap), and VPC flow logs enabled from day one.
- **FinOps discipline.** Karpenter-driven autoscaling defaults to ARM-based Graviton instances for system workloads — reflecting cost-consciousness valued at scale-conscious Japanese platforms — with explicit instance-type strategy and capacity-type defaults documented per environment.
- **Environment parity by design.** `dev` and `prod` share identical topology (same regions, same module composition); only sizing, retention windows, and API access CIDRs differ. This is a deliberate guard against the "works in dev, breaks in prod" anti-pattern that asymmetric environments produce.
- **DRY infrastructure via Terragrunt hierarchy.** Configuration cascades through `root.hcl` → `global.hcl` → `account.hcl` → `region.hcl` → module inputs, with `merge()` semantics for tags. Zero duplication across environment/region combinations.

### What this project demonstrates

This is not a tutorial follow-along. The work emphasizes:

- **Senior-level IAM design** — least-privilege scoped via tag conditions, not blanket permissions
- **Operational maturity** — explicit blast-radius reasoning, documented tradeoffs, clean teardown
- **Modern EKS patterns (2026)** — access entries, IRSA, Karpenter, eBPF networking, OIDC-based CI
- **Decision documentation** — every non-trivial choice has a rationale ("why per-AZ NAT," "why S3-native lockfile over DynamoDB," "why customer-managed KMS over AWS-managed")

### Status

Actively under development. See individual module READMEs for current phase status and design rationale. Public decision summaries are being extracted into `docs/decisions/` as each phase completes.

### Companion repository

Kubernetes manifests, Helm values, and ArgoCD Applications (App-of-Apps pattern) live in the companion GitOps repository:
**[eks-platform-gitops](https://github.com/RamiroCuenca/eks-platform-gitops)**

This repository handles the *infrastructure* (Terragrunt-managed AWS resources, EKS cluster, IAM, networking). The GitOps repo handles *what runs on the cluster* (workloads, controllers, configuration), reconciled continuously by ArgoCD.

### Reminders for the CI/CD pipeline phase

- **Use OIDC token exchange to assume an AWS role** in GitHub Actions — no static `AWS_ACCESS_KEY_ID` secrets. Configure the OIDC trust policy on AWS, reference the role ARN in the workflow, and capture screenshots of the token-exchange logs as evidence of supply-chain security maturity.

---
