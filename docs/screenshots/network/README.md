# Network module: deployment evidence

VPC `eks-platform-dev-ap-northeast-1` (`10.0.0.0/16`), `ap-northeast-1`, account `730269305302`. Captured 2026-05-14.

| File | What it proves |
|---|---|
| `vpc-overview.png` | VPC `Available`, `10.0.0.0/16` CIDR, DNS resolution + hostnames enabled, default tenancy. Matches the dev/ap-northeast-1 CIDR allocation declared in `global.hcl`. |
| `vpc-resource-map.png` | 6 subnets across 2 AZs in a public/private/intra three-tier split, 5 route tables, IGW + 2 NAT GWs + S3 + DynamoDB gateway endpoints, the whole network design in one frame. |
| `vpc-flow-logs.png` | Flow log `Active`, destination = CloudWatch Logs `/aws/vpc/.../flow-logs`, traffic type = `All`, dedicated IAM role, governance tags (`Project`, `Environment`, `ManagedBy=Terragrunt`, `Repository`). |
| `vpc-flow-logs-cloudwatch.png` | The flow log group with retention = 1 month and 6 live log streams (one per ENI) with recent timestamps, proves flow logs are not just configured, they're producing data. |
| `subnets-list.png` | All 6 subnets at a glance: CIDR, AZ, public/private/intra tier, and route-table association, confirms the per-AZ subnet topology lines up with the design. |
| `subnet-private-details.png` | Private subnet `10.0.32.0/20` (4091 usable IPs) in `ap-northeast-1a`, linked to the per-AZ private route table, proves subnet sizing accommodates EKS pod density. |
| `subnet-private-tags.png` | Private subnet tags: `kubernetes.io/role/internal-elb=1` (EKS internal LB auto-discovery), `karpenter.sh/discovery=<cluster>` (Karpenter subnet auto-discovery), `Tier=private`, and full governance tag set. |
| `subnet-public-tags.png` | Public subnet tags + `Auto-assign public IPv4=Yes`. `Tier=public` confirms the public/private semantic split is real, not just naming. |
| `nat-gateways.png` | 2 NAT gateways, one per AZ (`...nat-ap-northeast-1a`, `...nat-ap-northeast-1c`), both `Available` and `Zonal`, proves the per-AZ NAT design (no single-NAT cost-optimization shortcut). |
