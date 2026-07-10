# Autoscaling under load: deployment evidence

k6 load profiles run as in-cluster Jobs in the default-deny `loadtest` namespace
(scripts and manifests live in the demo-app repo under `loadtest/`), driving the
`go-demo` service through both scaling paths: CPU-driven HPA scale-out with
Karpenter provisioning the capacity, and queue-driven KEDA scale-from-zero on
Redis list depth. The queue profile deliberately overdrives the enqueue path
(~30× worker throughput) to exercise the scale-out; the residual backlog is
cleared administratively after capture, since scale-to-zero reacts to queue
depth, not drain history. Captured 2026-07-10.

## HTTP path — HPA + Karpenter

| File | What it proves |
|---|---|
| `01-hpa-scale-up.png` | `kubectl get hpa -w` during the run: `go-demo-server` climbs **2 → 10 replicas** as CPU utilization crosses the 60% target (peaking at 100%), each step visible in the watch stream. |
| `02-karpenter-nodeclaims.png` | `kubectl get nodeclaims -w`: seconds after the new replicas exceed steady-state capacity, Karpenter creates a new nodeclaim alongside the existing `c7g.large` on-demand node — just-in-time capacity, no pre-provisioned headroom. |
| `03-grafana-under-load.png` | The `go-demo / Service SLOs` dashboard over the run: request rate spiking, latency quantiles, HPA desired-vs-available climbing together, **0% 5xx** throughout. |
| `04-k6-http-summary.png` | k6 end-of-run summary: **555,440 requests at ~1,851 req/s, 0.00% failed, p95 = 8.95 ms** — against thresholds (`http_req_failed<5%`, `p95<1.5s`) that deliberately mirror the Prometheus alert rules, so the load test and the alerting judge the service by the same contract. |

## Queue path — KEDA from zero

| File | What it proves |
|---|---|
| `05-keda-scale-sequence.png` | `kubectl get deploy go-demo-worker -w`, the full lifecycle in one stream: **0 → 1 → 4 → 8 → 10 → 0**. KEDA wakes the worker from zero on Redis list depth, the HPA it manages steps up to max, and the cooldown returns it to zero — no idle worker pods outside the burst. |
| `05b-keda-scale-sequence.png` | The same window on the SLO dashboard: `/enqueue` request-rate plateau, worker replicas rising to 10, jobs processed at ~180/s (10 workers × 50 ms simulated work), then the descent back to zero. |
