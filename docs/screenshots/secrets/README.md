# Secrets Manager + IRSA (ASCP): deployment evidence

A demo workload retrieves a Secrets Manager secret through the AWS Secrets and Configuration Provider (ASCP) on the Secrets Store CSI driver, using a per-workload IRSA role scoped to the exact secret ARN. The secret is encrypted with a dedicated customer-managed KMS key, and the value is delivered to the pod as a tmpfs file mount, never synced into a Kubernetes Secret. Cluster `eks-platform-dev-ap-northeast-1`, `ap-northeast-1`, account `730269305302`. Captured 2026-06-29.

## Least-privilege IRSA

| File | What it proves |
|---|---|
| `01-irsa-policy-exact-arn.png` | The `…-demo-app-secrets` IRSA policy scopes `secretsmanager:GetSecretValue` / `DescribeSecret` to the **literal secret ARN** (`…:secret:eks-platform/dev/demo-app/credentials-80JJCT`), not a wildcard, and grants `kms:Decrypt` on the exact key ARN, gated by a `kms:ViaService = secretsmanager.ap-northeast-1.amazonaws.com` condition. Least privilege at both the secret and the key-usage layer. |
| `04-argocd-sa-role-annotation.png` | ArgoCD live manifest for the `demo-app` ServiceAccount in `demo`: the `eks.amazonaws.com/role-arn` annotation binds it to the IRSA role. The account-specific ARN reaches the public gitops repo through the ArgoCD cluster-Secret annotation bridge, never hardcoded. |

## Secret-at-rest encryption: dedicated CMK

| File | What it proves |
|---|---|
| `02-secret-cmk-encryption.png` | The demo secret `eks-platform/dev/demo-app/credentials` is encrypted with the dedicated `…-app-secrets` customer-managed key (not the default `aws/secretsmanager`); the description notes the value is Terraform-generated and never committed. This CMK is what forces the IRSA policy to carry the separate `kms:Decrypt` grant above, Secrets Manager decryption is a two-permission operation. |

## Mounted-secret retrieval

| File | What it proves |
|---|---|
| `03-pod-exec-cat-mounted-secret.png` | Top: both ArgoCD apps (`secrets-store-csi`, `secrets-demo`) Synced/Healthy. Middle: the `demo-app` SA carries the IRSA role-arn annotation. Bottom: `kubectl exec` cats the CSI-mounted secret file under `/mnt/secrets-store/…`, `{"password":"<blurred>","username":"demo_app"}`, delivered as a memory-backed tmpfs file, never synced into a Kubernetes Secret (so the value never lands in etcd). The password value is blurred; it is a generated demo credential. |
