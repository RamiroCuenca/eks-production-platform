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
