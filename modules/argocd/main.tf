# ArgoCD bootstrap.
#
# This is the single, deliberately-bounded place where Terraform owns
# in-cluster declarative state. The pattern:
#
#   1. Install the ArgoCD Helm chart.
#   2. Write a Kubernetes Secret carrying per-cluster facts that the gitops
#      repo's ApplicationSets read at sync time. Account-specific values
#      (IRSA role ARNs, SQS queue names) flow through this Secret, never
#      through Git.
#   3. Create a single root ArgoCD Application pointing at the gitops repo's
#      apps/ directory. ArgoCD then discovers every ApplicationSet there,
#      and the cluster-generator pattern fans them out across whichever
#      clusters' Secrets exist.
#
# Once those three resources exist, Terraform steps out: every subsequent
# controller, CRD, and workload lifecycle is owned by ArgoCD reading from
# the gitops repo.

locals {
  # Carried into the cluster Secret as a label so gitops ApplicationSets can
  # target environments selectively (e.g. matchLabels: { env: dev }).
  cluster_secret_labels = {
    "argocd.argoproj.io/secret-type" = "cluster"
    env                              = var.environment
    region                           = var.aws_region
  }

  # Per-cluster facts injected into ApplicationSets at render time via
  # {{ .values.* }}. Everything here is something only Terraform can know
  # (it owns the AWS resources the values refer to).
  cluster_secret_values = {
    clusterName                = var.cluster_name
    awsRegion                  = var.aws_region
    karpenterControllerRoleArn = var.karpenter_controller_role_arn
    karpenterNodeRoleName      = var.karpenter_node_role_name
    karpenterInterruptionQueue = var.karpenter_interruption_queue_name
  }
}

# ---------- Namespace ----------
#
# Created explicitly rather than via Helm's create_namespace so we can apply
# labels and so the Secret resource has a guaranteed parent during apply.

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ---------- Helm install ----------

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # Wait for the rollout to complete before downstream resources (root
  # Application, cluster Secret consumers) try to talk to the ApplicationSet
  # controller.
  wait    = true
  timeout = 600

  values = [yamlencode(local.argocd_values)]
}

locals {
  argocd_values = merge(
    {
      global = {
        # Pin every component to the system MNG; Karpenter-launched nodes
        # don't exist yet at first apply and ArgoCD must not depend on them.
        affinity = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [{
                matchExpressions = [{
                  key      = "karpenter.sh/nodepool"
                  operator = "DoesNotExist"
                }]
              }]
            }
          }
        }
      }
      configs = {
        # Public UI is intentionally disabled — only port-forwarded admin
        # access for the portfolio lifecycle. Future work documented in
        # journal: AWS LB Controller + OIDC SSO.
        params = {
          "server.insecure" = false
        }
      }
      server = {
        service = {
          type = "ClusterIP"
        }
      }
    },
    var.ha_enabled ? local.argocd_ha_values : local.argocd_single_replica_values,
  )

  # Dev posture: single replicas everywhere, no redis-ha. ~150Mi memory total.
  argocd_single_replica_values = {
    controller          = { replicas = 1 }
    server              = { replicas = 1 }
    repoServer          = { replicas = 1 }
    applicationSet      = { replicas = 1 }
    redis-ha            = { enabled = false }
    redis               = { enabled = true }
  }

  # Prod posture: multi-replica controllers and redis-ha. The chart's own
  # PDBs ship by default once replicas > 1.
  argocd_ha_values = {
    controller     = { replicas = 2 }
    server         = { replicas = 2 }
    repoServer     = { replicas = 2 }
    applicationSet = { replicas = 2 }
    redis-ha       = { enabled = true }
    redis          = { enabled = false }
  }
}

# ---------- Cluster Secret ----------
#
# ArgoCD's ApplicationSet cluster generator iterates over Secrets labeled
# argocd.argoproj.io/secret-type=cluster in the argocd namespace. The local
# cluster (this one — where ArgoCD itself is running) is implicitly known
# to ArgoCD as `in-cluster` with no Secret, so the cluster generator's
# selector skips it. Creating this Secret pointing at the local API
# endpoint registers the cluster as a "remote" target that the generator
# picks up, AND lets us attach `config.values` carrying the per-cluster
# facts the ApplicationSets templates reference.

resource "kubernetes_secret" "cluster" {
  metadata {
    name      = var.cluster_name
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels    = local.cluster_secret_labels
  }

  type = "Opaque"

  data = {
    # ArgoCD's required cluster-Secret fields.
    name   = var.cluster_name
    server = "https://kubernetes.default.svc"
    # `config` carries cluster connection metadata AND the values block the
    # gitops ApplicationSets read via {{ .values.* }}.
    config = jsonencode({
      tlsClientConfig = {
        insecure = false
      }
      values = local.cluster_secret_values
    })
  }

  depends_on = [helm_release.argocd]
}

# ---------- Root Application ----------
#
# Points ArgoCD at the gitops repo's apps/ directory. ArgoCD walks the
# directory, discovers every ApplicationSet, and each ApplicationSet then
# stamps out Applications per matching cluster Secret.
#
# `directory.recurse = true` so subdirectories under apps/ also get picked
# up as additional ApplicationSets land.
#
# Created via the kubectl provider rather than hashicorp/kubernetes's
# kubernetes_manifest: the Application CRD is installed by the ArgoCD Helm
# chart in the same apply, and kubernetes_manifest would fail the plan
# because it validates manifests against their CRD schemas before apply.
# kubectl_manifest defers validation to apply time, which is the canonical
# bootstrap pattern for any in-cluster resource whose CRD is installed by
# the same Terraform run.

resource "kubectl_manifest" "root_application" {
  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      # Empty finalizers list on the App-of-Apps root so a `kubectl delete
      # application root` doesn't cascade-prune every child; children own
      # their own resources' lifecycle through their own finalizers.
      finalizers = []
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_repo_target_revision
        path           = "apps"
        directory = {
          recurse = true
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "ServerSideApply=true",
        ]
      }
    }
  })

  depends_on = [helm_release.argocd]
}
