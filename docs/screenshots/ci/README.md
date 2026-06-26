# GitHub Actions OIDC federation — deployment evidence

CI identity for GitHub Actions on account `730269305302`: a federated OIDC
identity provider plus per-environment IAM roles (`eks-platform-ci-dev`,
`eks-platform-ci-prod`), each capped by a permissions boundary. No static AWS
keys exist in GitHub. Captured 2026-06-10. This directory grows with the CI
pipeline itself — workflow-run and scanner evidence lands alongside these IAM
shots as each pipeline ships.

## OIDC trust chain

| File | What it proves |
|---|---|
| `00-github-oidc-provider.jpeg` | IAM → Identity providers: `token.actions.githubusercontent.com` registered as an OpenID Connect provider — the federation trust anchor every CI role assumption flows through. |
| `01-iam-ci-dev-trust.png` | `eks-platform-ci-dev` → Trust relationships: federated principal is the GitHub OIDC provider, `aud` pinned to `sts.amazonaws.com`, and `sub` limited to `repo:RamiroCuenca/eks-production-platform:pull_request` OR `:ref:refs/heads/main` — PRs can plan, merges to main can apply, nothing else can assume the role. |
| `02-iam-ci-prod-trust.png` | `eks-platform-ci-prod` → Trust relationships: `sub` trusts only `repo:RamiroCuenca/eks-production-platform:environment:prod`. GitHub refuses to stamp that claim into a token unless the run passed the `prod` Environment's protection rules, so the human approval gate is enforced by the token issuer itself, not by the workflow file. |

## Permissions boundary

| File | What it proves |
|---|---|
| `03-iam-ci-role-boundary.png` | `eks-platform-ci-dev-boundary` policy JSON, top: the `PermissionsCeiling` Allow (a boundary grants nothing by itself) and `DenyOutsideAllowedRegions` pinning all regional actions to `ap-northeast-1` / `ap-northeast-2` via `aws:RequestedRegion`. |
| `03b-iam-ci-role-boundary-denies.png` | Same policy, continued: `DenyLongLivedCredentials` (no IAM users, access keys, or login profiles minted from CI), `DenyAccountAliasChanges`, and `DenyKmsKeyDestruction` — the categories no attached policy can ever re-enable. |

## Secrets scanning gate (gitleaks)

| File | What it proves |
|---|---|
| `04-gitleaks-fail.png` | The gate firing during a live canary test: a fake AWS access key committed to the PR branch is caught by the full-history scan — rule `aws-access-token` identified, the secret itself `REDACTED` in the log output, file/commit/fingerprint pinpointed, job exits 1 and fails the check. |
| `05-gitleaks-pass.png` | The same workflow green after the canary was removed by **history rewrite**. A plain revert commit would have stayed red — the credential would still be live in git history — so the full-history posture forces the honest remediation, not a cosmetic one. |

## SAST gate (semgrep)

| File | What it proves |
|---|---|
| `08-semgrep-fail.png` | The gate failing its very first CI run on a real finding, not a staged one: `p/terraform` flagged `map_public_ip_on_launch = true` on the public subnets — a default-open setting the Trivy gate had not caught, concrete evidence for running overlapping scanners with different rule coverage. |
| `08b-semgrep-pass.png` | The same job green after the fix landed — the attribute was removed rather than suppressed, since nothing launched in public subnets needs an auto-assigned address (NAT gateways use EIPs, load balancers attach their own). 108 rules across Terraform, workflow, and Dockerfile packs, 0 findings. |
| `08c-semgrep-k8s-fail.png` | The Kubernetes-specific rule pack on the gitops repository rejecting a privileged debug pod — four blocking findings from one manifest (privileged container, privilege escalation, writable root filesystem), each with the rule's rationale and suggested fix inline in the log. |

## Dependency hygiene (Dependabot)

| File | What it proves |
|---|---|
| `19-dependabot-settings.png` | Advanced Security settings with the full Dependabot stack enabled — dependency graph, vulnerability alerts, and automated security updates — alongside the committed version-update config that keeps the SHA-pinned workflow actions current. Captured on the gitops repo; both repositories carry the same configuration. |
| `20-dependabot-pr-opened.png` | Dependabot opening PR #22 unprompted — a **grouped** `github_actions` version update (`actions/checkout` 6.0.3 → 7.0.0) carrying the `dependencies` and `github_actions` labels. Grouping is deliberate config: related action bumps arrive as one reviewable PR instead of a swarm of single-line ones. |
| `20b-dependabot-pr-checks-green.png` | The same PR "Ready to merge" with the CI checks green and the bump commit GPG-`Verified` — the bot's change is held to the identical branch-protection bar (secrets, SAST, validation) as any human PR before it can land. |
| `20c-dependabot-pr-sha-pinned-bump.png` | Files-changed view: the bump rewrites the **commit-SHA pin** of `actions/checkout` across all three workflows (`sast`, `secrets-scan`, `terraform`) and updates the trailing `# v6.0.3` → `# v7.0.0` comment — proof the SHA-pinning supply-chain posture is maintained automatically, not eroded back into floating tags. |
| `20d-dependabot-pr-merged.png` | The PR merged into `main` after human review, closing the loop: the bot proposes, the required gates verify, a human approves. Automated dependency currency without unattended merges. |

## Manifest validation gates (kubeconform + helm)

| File | What it proves |
|---|---|
| `09-kubeconform-fail.png` | The kubeconform gate rejecting an ApplicationSet with an unknown apiVersion during a fail-closed verification: "could not find schema" is a hard error, not a skip, so a resource the validator doesn't recognize can never reach ArgoCD unvalidated. |
| `10-helm-lint-fail.png` | The helm gate failing the same run on a deliberate template parse error. The step header documents the subtle part: without `pipefail`, a failed `helm template` hands kubeconform an empty stream that validates vacuously green — the gate is wired to fail on render errors, not just invalid output. |

## Terraform pipeline + OIDC federation in action

| File | What it proves |
|---|---|
| `06c-terraform-run-all-green.png` | The full pipeline green on one PR run: validate, changed-unit detection, scoped dev + prod plans, and the Trivy config scan — with the Deployment protection rules panel showing the prod gate was approved by a human four minutes before the prod plan ran. |
| `15-oidc-token-exchange.png` | The `plan (dev)` job's step list: "Assume ci-dev via OIDC" exchanges the workflow's federated token for short-lived STS credentials in one second — no static AWS keys exist anywhere in the repository or its secrets. |
| `15b-prod-approval-waiting.png` | The same workflow holding `plan (prod)` in a waiting state while everything else completed — the job cannot start (and its `environment:prod` token cannot exist) until the required reviewer acts. |
| `15c-prod-approval-dialog.png` | The reviewer-side gate: GitHub's "Review pending deployments" approval dialog for the `prod` environment. |
| `16-cloudtrail-oidc-assume.png` | AWS-side proof: the CloudTrail `AssumeRoleWithWebIdentity` event for `eks-platform-ci-prod`, whose `userName` is the federated sub claim itself — `repo:RamiroCuenca/eks-production-platform:environment:prod`. |
| `16b-cloudtrail-oidc-event-json.png` | The full event record: `identityProvider: token.actions.githubusercontent.com`, the OIDC principal, the GitHubActions role session, and the one-hour session duration — the complete token-exchange audit trail as AWS recorded it. |

## Deliberate-failure verification — every gate red, then green, on one PR

A single commit planted one violation per gate — a shape-valid fake credential, a workflow script-injection pattern, an unencrypted bucket, an undeclared variable reference — and the same pull request was then brought back to green. The PR is preserved unmerged so the run history stays clickable. (A paired-credential variant never reached CI at all: GitHub push protection rejected it server-side, one layer ahead of these gates.)

| File | What it proves |
|---|---|
| `11-proof-pr-all-red.png` | The merge box with all four gates failing simultaneously on one commit — secrets, SAST, IaC misconfiguration, and configuration validity — each tagged **Required**, so no path to merge exists while any gate is red. Plan jobs correctly skipped: the planted files touched no deployable infrastructure paths. |
| `12-proof-pr-finding-detail.png` | Inside the failing secrets gate: rule `aws-access-token`, the secret `REDACTED` in the output, entropy score, and the exact file/line/commit fingerprint — the log pinpoints the leak without ever re-printing it. |
| `06-terraform-validate-fail.png` | The validate gate rejecting a reference to an undeclared variable — configuration errors stop at the PR, before any plan or apply could encounter them. |
| `07-trivy-config-fail.png` | The IaC gate red on a deliberately unencrypted bucket, proving the suppression model: the existing carve-out for the state bucket is scoped to that one resource, so a new unencrypted bucket anywhere else still fails the build. |
| `13-proof-pr-all-green.png` | The same PR fully green — with the force-push visible in the timeline, because that *is* the remediation: a revert would have left the credential live in git history and the full-history secrets gate red by design. |

## Enforcement wiring

| File | What it proves |
|---|---|
| `17-branch-protection-infra.png` | The infra repo's ruleset on `main`: all seven checks required — secrets, validation, changed-unit detection, both environment plans, IaC scanning, SAST — plus force-push blocking. A gate that isn't required is advisory; these are not. |
| `18-branch-protection-gitops.png` | The gitops repo's ruleset: pull request required, force-pushes blocked, and all four checks (secrets, SAST, kubeconform, helm) required before anything reaches the branch ArgoCD reconciles from. |
| `14-readme-badges.png` | The public repo front page with every workflow badge green on `main` — the steady state all of the above enforces. |
