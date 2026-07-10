# Application runtime: deployment evidence

The `go-demo` workload (server + queue worker + db-init Job) running live in the
`demo` namespace against Aurora PostgreSQL and ElastiCache Redis: GitOps-delivered
through ArgoCD sync waves, secrets mounted via the CSI Secrets Store, data-tier
egress pinned by FQDN network policy, and both autoscaling paths armed at rest.
Captured 2026-07-10.

## Delivery & data path

| File | What it proves |
|---|---|
| `01-argocd-full-tree.png` | ArgoCD root application tree, every application **Synced/Healthy** — the full platform (CNI, controllers, observability, workloads) reconciled from git. |
| `02-db-init-job.png` | Logs of the wave-ordered `go-demo-db-init` Job: the application role is created **CONNECT-only** (least privilege, not owner), with idempotent re-run wording — schema setup is a first-class, ordered GitOps step, not a manual action. |
| `03-app-db-cache-enqueue.png` | One terminal, four live calls: `/healthz`, `/db` (row over TLS to Aurora), `/cache` (write+read over TLS+AUTH to Redis), `/enqueue` → `202` — the functional path across the whole data tier. |
| `05-hubble-datatier-allow.png` | Hubble flows to ports 5432 and 6379 with verdict **FORWARDED**, attributable by hostname through the workload-owned `toFQDNs` policy — the allow half of the zero-trust story (the deny-by-default half is evidenced in `../cilium/`). |

## Secrets delivery

| File | What it proves |
|---|---|
| `04-secret-mount-and-sync.png` | `exec ls` into the server **fails** — distroless image, no shell: the error is the hardening evidence. The CSI driver's `SecretProviderClassPodStatus` attests what was mounted into tmpfs instead, and `go-demo-redis-auth` is the single deliberately ASCP-mirrored Kubernetes Secret (consumed by KEDA's TriggerAuthentication, which cannot read a file mount). |

## Autoscaling at rest

| File | What it proves |
|---|---|
| `06-autoscaling-at-rest.png` | `hpa`, `scaledobject` and deployments at steady state: the server at HPA minReplicas with a **live CPU metric** (no `<unknown>`), and the worker at **0/0** — KEDA scale-to-zero working as designed, not a failure state. |

## DAST

| File | What it proves |
|---|---|
| `07-zap-baseline.png` | OWASP ZAP baseline scan against the live service: **66 PASS / 1 WARN / 0 FAIL** — security headers all pass (middleware verified at runtime); the single WARN is cacheable 404 responses. Honest caveat: the spider found 3 URLs — a JSON API exposes little surface to a baseline crawl, so this is a shallow DAST by nature. |
