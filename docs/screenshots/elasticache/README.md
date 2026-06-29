# ElastiCache Redis — deployment evidence

ElastiCache Redis `7.1.0` deployed as the replication group `eks-platform-dev-ap-northeast-1-redis` — cluster mode disabled, primary + replica across Availability Zones (`cache.t4g.micro`, `ap-northeast-1`, account `730269305302`). At-rest (customer-managed KMS) and in-transit (TLS) encryption plus an AUTH token are all enabled; the cache sits in no-internet-route intra subnets and admits traffic only from the EKS cluster security group. Captured 2026-06-29.

## Topology, HA & encryption

| File | What it proves |
|---|---|
| `01-replication-group-overview.png` | Cluster details: Redis `7.1.0`, **cluster mode Disabled**, **Multi-AZ Enabled**, **Auto-failover Enabled**, **Encryption at rest Enabled**, **Encryption in transit Enabled** with **transit mode Required**, 2 nodes — every HA and encryption property on one page. Cluster mode is disabled deliberately: HA and encryption without the sharding a single-shard demo never exercises. |
| `02-nodes-multi-az.png` | Nodes tab: `-redis-001` (primary) and `-redis-002` (replica) in **different AZs** — the Multi-AZ replica placement that backs automatic failover. |
| `03-encryption-at-rest-transit.png` | The cache's at-rest encryption key is the customer-managed `…-redis` CMK (key ARN shown, not the default `aws/elasticache`), with AUTH default-user access enabled. |

## Credentials & connection details

| File | What it proves |
|---|---|
| `04-connection-auth-secret.png` | `eks-platform/dev/redis/connection` = `{auth_token, port, primary_endpoint, reader_endpoint}`, encrypted with the `…-redis` CMK. The AUTH token value is blurred — it is a live credential. |

## Network isolation

| File | What it proves |
|---|---|
| `05-cache-subnet-group-intra.png` | Cache subnet group over the same two **intra** subnets as Aurora (`10.0.64.0/20` & `10.0.80.0/20`, AZs `1a` / `1c`) — no route to a NAT or internet gateway. |
| `06-security-group-cluster-ingress.png` | The `…-redis` security group admits inbound TCP **6379** only from the **EKS cluster security group** (`sg-0ebfa621…`, a security-group *reference* — not a CIDR), with zero outbound rules. |

## Live connectivity

| File | What it proves |
|---|---|
| `07-pod-connect-tls-auth.png` | An in-cluster throwaway pod runs `redis-cli --tls -a "$REDIS_AUTH" PING` → `PONG`. Proves cluster-SG ingress works under Cilium ENI-IPAM, and that in-transit TLS and AUTH are both required and satisfied. (`--insecure` skips only CA-chain verification of the ElastiCache server cert; the connection is still TLS-encrypted and AUTH-gated.) |
