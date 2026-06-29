# Aurora PostgreSQL — deployment evidence

Aurora PostgreSQL `16.6` provisioned as a Multi-AZ cluster `eks-platform-dev-ap-northeast-1-aurora` (writer + reader, `db.t4g.medium`, `ap-northeast-1`, account `730269305302`). Storage, the RDS-managed master credential, and the connection secret are all encrypted with a dedicated customer-managed KMS key; the cluster sits in no-internet-route intra subnets and admits traffic only from the EKS cluster security group, with TLS enforced server-side. Captured 2026-06-29.

## Cluster & Multi-AZ topology

| File | What it proves |
|---|---|
| `00-apply-order.png` | `terragrunt apply` of the two independent data units — ElastiCache (`9 added`) and Aurora (`11 added`, `Creation complete after 9m54s`) — applying cleanly with timings. The two modules share no state and have no dependency edge between them. |
| `01-rds-cluster-overview.png` | RDS → cluster overview: a regional Aurora PostgreSQL cluster with a writer and a reader, master credentials managed in Secrets Manager. |
| `02-instances-multi-az.png` | Instances list: writer in `ap-northeast-1a` and reader in `ap-northeast-1c` — writer and reader in **different AZs**, the Multi-AZ failover topology read directly off the console. |

## Encryption at rest — customer-managed KMS

| File | What it proves |
|---|---|
| `03-storage-encryption-cmk.png` | Configuration tab: storage **encrypted** with the customer-managed `…-aurora` KMS key (not the default `aws/rds`), provisioned engine, Multi-AZ across 2 zones, deletion protection disabled (dev). |
| `04-managed-master-secret-rotation.png` | The RDS-managed master secret (`rds!cluster-…`) in Secrets Manager: encrypted with the `…-aurora` CMK, **rotation Enabled on a 7-day schedule** — AWS owns the rotation, no custom Lambda to deploy or grant VPC reachability. |
| `06-connection-secret.png` | `eks-platform/dev/aurora/connection` holds only non-sensitive connection facts (`host`, `reader_host`, `port`, `dbname`) encrypted with the `…-aurora` CMK; the credentials stay in the RDS-managed master secret, never copied here. |

## Network isolation

| File | What it proves |
|---|---|
| `07-db-subnet-group-intra.png` | DB subnet group over two **intra** subnets (`…-intra-…1a` / `…-intra-…1c`, `10.0.64.0/20` & `10.0.80.0/20`) across two AZs — the subnet tier with no route to a NAT or internet gateway, so the database cannot initiate outbound internet traffic. |
| `08-security-group-cluster-ingress.png` | The `…-aurora` security group admits inbound TCP **5432** only from the **EKS cluster security group** (`sg-0ebfa621…`, a security-group *reference* — not a CIDR), with zero outbound rules. "Reachable from the cluster, nothing else." |

## TLS enforcement & live connectivity

| File | What it proves |
|---|---|
| `05-force-ssl-param.png` | The custom DB cluster parameter group (`…-aurora`, family `aurora-postgresql16`) that carries `rds.force_ssl = 1`. The enforcement itself is demonstrated functionally in `09b`. |
| `09-pod-connect-tls.png` | An in-cluster throwaway pod connects over TLS (`sslmode=require`) and runs `select version()` → `PostgreSQL 16.6`. Proves cluster-SG ingress works under Cilium ENI-IPAM **and** TLS is accepted. |
| `09b-pod-connect-tls.png` | The same connection with `sslmode=disable` is **rejected** — `FATAL: … no encryption` — proving `rds.force_ssl = 1` is enforced server-side: a non-TLS client cannot connect, regardless of its configuration. |
