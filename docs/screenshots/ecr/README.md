# ECR registry + application CI identity: deployment evidence

The application repository's pipeline publishes a multi-arch container image to a private ECR repository on every merge to `main`, authenticating through GitHub OIDC federation into a role that only main-branch tokens can assume. The registry enforces immutable tags, scans on push, and persists across infrastructure teardowns so the GitOps-pinned tag never dangles. Registry `eks-platform/demo-app`, `ap-northeast-1`, account `730269305302`. Captured 2026-07-04/05.

## Registry hardening

| File | What it proves |
|---|---|
| `01-repo-settings-immutable-scan.png` | Repository details: **Tag mutability: Immutable** (a tag can never be repointed, so the tag promoted into gitops is provably the image that passed the pipeline's gates), **Scan on push** enabled, **AES-256** at-rest encryption — the CMK pattern is deliberately reserved for confidential data stores; this is the platform's one 24/7-persistent resource. |
| `02-lifecycle-policy.png` | The two lifecycle rules: untagged images expire after one day (multi-arch/build leftovers are waste), and only the 10 most recent tagged images are retained — bounded storage regardless of merge cadence. |

## Immutable, multi-architecture artifacts

| File | What it proves |
|---|---|
| `03-image-immutable-sha-tag.png` | The images list after the first publish: one **Image Index** tagged with the full commit SHA — one immutable tag per merge, no moving `latest` — plus its two untagged platform children. |
| `04-image-multi-arch-manifests.png` | An Image Index's Manifests table: `linux/amd64` and `linux/arm64` children, matching the cluster's Graviton-first node pools with amd64 fallback. Built by native Go cross-compilation (no QEMU). The index shown is the **second** publish, triggered autonomously by a Dependabot dependency-bump merge — the pipeline running with no human staging. The index itself reports "Scan not found", which pairs with the next shot. |
| `05-scan-on-push-child-manifest.png` | ECR basic scanning operates on platform *images*, not multi-arch *indexes*: the arm64 child shows **Scan status: Complete** with zero findings across all severities (consistent with a distroless base and a static binary). Registry-side verification behind the pipeline's gating Trivy scan, which fails the build on HIGH/CRITICAL before anything is pushed. |

## CI identity: OIDC-federated, main-only

| File | What it proves |
|---|---|
| `06-iam-ci-app-trust-main-only.png` | The `eks-platform-ci-app` trust policy: `sts:AssumeRoleWithWebIdentity` from the GitHub OIDC provider, with `sub` pinned to `repo:RamiroCuenca/eks-platform-demo-app:ref:refs/heads/main` and `aud` pinned to STS. Pull requests never hold a cloud identity — a malicious PR cannot even authenticate, never mind push. |
| `07-publish-run-oidc.png` | The merge-to-main run: `build & test` and `container image scan` gate the `publish image` job — nothing reaches the registry without green gates. |
| `07b-publish-oidc-step-log.png` | The publish job's `authenticate to AWS` step log: "Assuming role with OIDC" → authenticated as the assumed-role session. No static AWS keys exist anywhere in the repository or its secrets. |
| `08-pr-publish-skipped.png` | The same workflow on a pull request: `publish image` is **skipped** while the build/scan gates still run — the PR-holds-no-identity design visible in the UI. |
| `09-cloudtrail-assume-role-list.png` | CloudTrail's `AssumeRoleWithWebIdentity` events with each caller's OIDC **sub claim as the user name**: the app repo's `ref:refs/heads/main` publishes alongside the infra repo's `environment:prod` plan — the whole CI identity model in one view, every assumption attributable to a repo and context. |
| `09b-cloudtrail-assume-role-detail.png` | One publish event's full record: `userName` and `subjectFromWebIdentityToken` carry the main-ref sub claim, the assumed role is `eks-platform-ci-app`, and the credentials are a short-lived session — the AWS-side half of the exchange shown in `07b`. |

## The delivery loop, closed

| File | What it proves |
|---|---|
| `10-promotion-pr-automerged.png` | The first automated promotion: the pipeline-opened PR in the gitops repository — a one-line diff moving the pinned image tag to the artifact just published — with auto-merge enabled, all four of that repository's validation gates passed, and the merge landing with no human touch. Every deployment is an auditable Git event that cleared the same checks as a human change; no actor bypasses branch protection. |
| `10b-ci-run-full-chain.png` | The complete delivery chain in one run: build/test and the container scan gate the publish, and the promotion runs only after the image exists in the registry. Merge → gates → multi-arch publish → auto-merged promotion → ArgoCD reconciles. |
