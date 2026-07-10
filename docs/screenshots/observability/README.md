# Observability stack: deployment evidence

kube-prometheus-stack, Loki and Alloy delivered through ArgoCD, with Prometheus
scraping workloads across default-deny namespaces via an explicit
`allow-monitoring-scrape` ingress policy. Monitoring components are pinned to
the stable system node tier so the observer never rides the ephemeral capacity
it watches; time-series and log storage sit on dynamically provisioned,
encrypted gp3 volumes. Captured 2026-07-10.

## Placement & storage

| File | What it proves |
|---|---|
| `01-monitoring-pods-pvcs.png` | Monitoring pods scheduled on **system nodes** (not Karpenter capacity), with the Prometheus and Loki PVCs **Bound** on the `gp3` StorageClass. |
| `01b-monitoring-pods-pvcs.png` | EC2 console view of the two backing EBS volumes, both **encrypted**. |

## Scrape path through default-deny

| File | What it proves |
|---|---|
| `02-prometheus-targets.png` | Prometheus targets page: `cilium-agent`, `cilium-operator`, Hubble and the `go-demo` ServiceMonitor all **UP** — the scrape path works through the namespace's default-deny floor. The worker PodMonitor shows no targets here because the worker is scaled to zero: nothing to scrape is the correct state at rest. |
| `02b-worker-podmonitor-up.png` | The same page while the worker is scaled out under queue load: `podMonitor/demo/go-demo-worker` at **10/10 UP** with per-pod labels — completing the pair: zero targets at rest, full discovery within seconds of KEDA waking the deployment. |

## Dashboards & logs

| File | What it proves |
|---|---|
| `03-grafana-go-demo-slo.png` | The custom `go-demo / Service SLOs` dashboard under live traffic: request rate by route, 5xx ratio, latency quantiles, HPA and worker scale panels — one screen answering "is the service healthy and why". |
| `04-grafana-hubble-network.png` | The Hubble network dashboard with flow verdicts including a **DROP** registered from a policy-denied probe — network policy enforcement is observable, not just declared. |
| `05-grafana-cluster-fleet.png` | Built-in kube-prometheus-stack fleet view — node/cluster-level resource picture alongside the service-level dashboards. |
| `06-loki-demo-logs.png` | Grafana Explore → Loki, `{namespace="demo"}` streaming live application logs — the Alloy → Loki collection path end to end. |

## Alerting

| File | What it proves |
|---|---|
| `07-alert-firing.png` | `WorkloadPodRestartStorm` **firing** against a deliberately crash-looping pod — the alert pipeline evidenced end to end (rule evaluation → Alertmanager), not just rules loaded. |
