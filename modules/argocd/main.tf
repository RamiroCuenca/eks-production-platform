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
  # Labels drive selector matching: gitops ApplicationSets use
  # matchLabels: { argocd.argoproj.io/secret-type: cluster } to find this
  # Secret, and env/region are available as targeting axes if some
  # ApplicationSet wants to apply only to dev or only to ap-northeast-1.
  cluster_secret_labels = {
    "argocd.argoproj.io/secret-type" = "cluster"
    env                              = var.environment
    region                           = var.aws_region
  }

  # Per-cluster facts injected into ApplicationSet templates at render
  # time. Stored as ANNOTATIONS because ArgoCD's cluster generator only
  # exposes labels and annotations from the cluster Secret to the template
  # — anything stashed in data.config (where the v1 of this module put it)
  # is parsed as connection config and silently dropped. ARNs contain ':'
  # and '/' which are illegal in label values, so the whole bundle lives
  # in annotations for consistency.
  #
  # The gitops repo's ApplicationSets dereference these via a generator
  # `values` block (one place, one time) so the chart template body stays
  # readable with {{ .values.* }} references.
  cluster_secret_annotations = {
    "platform.io/cluster-name"                  = var.cluster_name
    "platform.io/aws-region"                    = var.aws_region
    "platform.io/karpenter-controller-role-arn" = var.karpenter_controller_role_arn
    "platform.io/karpenter-node-role-name"      = var.karpenter_node_role_name
    "platform.io/karpenter-interruption-queue"  = var.karpenter_interruption_queue_name
    "platform.io/demo-app-secrets-role-arn"     = var.demo_app_secrets_role_arn
    "platform.io/demo-secret-name"              = var.demo_secret_name

    # Go demo app. The split is by secrecy of the value: non-secret,
    # Terraform-owned facts (endpoints, ports, the registry URL, role ARNs)
    # travel here and become plain pod env / image fields in the chart, while
    # secret material (DB password, Redis AUTH token) is delivered only as
    # CSI-mounted tmpfs files. The master secret is referenced by ARN because
    # RDS names it (`rds!cluster-…`) — ASCP accepts full ARNs as objectName.
    "platform.io/go-demo-secrets-role-arn"     = var.go_demo_secrets_role_arn
    "platform.io/go-demo-db-init-role-arn"     = var.go_demo_db_init_role_arn
    "platform.io/go-demo-db-secret-name"       = var.go_demo_db_secret_name
    "platform.io/go-demo-db-user"              = var.go_demo_db_username
    "platform.io/go-demo-image-repository"     = var.ecr_repository_url
    "platform.io/aurora-master-secret-arn"     = var.aurora_master_secret_arn
    "platform.io/aurora-writer-endpoint"       = var.aurora_writer_endpoint
    "platform.io/aurora-port"                  = var.aurora_port
    "platform.io/aurora-database"              = var.aurora_database_name
    "platform.io/redis-primary-endpoint"       = var.redis_primary_endpoint
    "platform.io/redis-port"                   = var.redis_port
    "platform.io/redis-connection-secret-name" = var.redis_connection_secret_name
  }
}

# ---------- Helm install ----------
#
# The namespace is intentionally NOT managed as a separate kubernetes_namespace
# resource. ArgoCD installs a ValidatingWebhookConfiguration (failurePolicy:
# Fail) that blocks any resource delete once argocd-server is down, causing the
# namespace to hang indefinitely in Terminating state. Helm uninstall never
# deletes the namespace by default, so the EKS cluster destroy cleans it up
# with no intervention. create_namespace = true covers the install side.

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true

  # Wait for the rollout to complete before downstream resources (root
  # Application, cluster Secret consumers) try to talk to the ApplicationSet
  # controller.
  wait    = true
  timeout = 600

  values = [yamlencode(local.argocd_values)]
}

locals {
  # The system MNG carries a `node-tier=system:NoSchedule` taint to keep
  # application workloads off it. Every cluster-critical component — ArgoCD
  # included — must tolerate the taint or stay Pending on a fresh cluster
  # where no untainted nodes exist yet. Centralised here so the value is
  # reused in both global and per-component blocks below.
  system_toleration = {
    key      = "node-tier"
    operator = "Equal"
    value    = "system"
    effect   = "NoSchedule"
  }

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
        # Inherited by every long-running component (server, controller,
        # repo-server, applicationset, notifications, dex).
        tolerations = [local.system_toleration]
      }
      # The redis-secret-init pre-install Helm hook does NOT inherit
      # global.tolerations in chart 7.8.x — its template references
      # `.Values.redisSecretInit.tolerations` directly. Must be set
      # explicitly or the helm install hangs forever waiting for the hook
      # pod to schedule. Same for the redis Deployment itself: per-component
      # tolerations override (rather than merge with) global, so we set it
      # explicitly to be safe.
      redisSecretInit = {
        tolerations = [local.system_toleration]
      }
      redis = {
        tolerations = [local.system_toleration]
      }
      configs = {
        # Public UI is intentionally disabled — only port-forwarded admin
        # access for the portfolio lifecycle. Future work documented in
        # journal: AWS LB Controller + OIDC SSO.
        params = {
          "server.insecure" = false
        }
        # Cluster-wide diff customisations applied to every Application.
        # Lives in the argocd-cm ConfigMap, so adding a new chart never
        # has to repeat these workarounds.
        cm = {
          # Kubernetes 1.33+ added `.status.terminatingReplicas` on
          # Deployments and ReplicaSets (KEP-3973). ArgoCD 2.14.x ships
          # an OpenAPI schema that predates that field, so its structured
          # merge diff (triggered by ServerSideApply=true) refuses to
          # build a typed value from the live resource and emits:
          #   "field not declared in schema"
          # The field is owned by kube-controller-manager — ArgoCD never
          # writes it — so ignoring it has no operational effect. The
          # proper fix is to bump ArgoCD to a release whose bundled
          # schema knows the field; tracked for the next upgrade window.
          "resource.customizations.ignoreDifferences.apps_Deployment" = <<-EOT
            jsonPointers:
              - /status/terminatingReplicas
          EOT
          "resource.customizations.ignoreDifferences.apps_ReplicaSet" = <<-EOT
            jsonPointers:
              - /status/terminatingReplicas
          EOT
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
    controller     = { replicas = 1 }
    server         = { replicas = 1 }
    repoServer     = { replicas = 1 }
    applicationSet = { replicas = 1 }
    redis-ha       = { enabled = false }
    redis          = { enabled = true }
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
    name        = var.cluster_name
    namespace   = var.argocd_namespace
    labels      = local.cluster_secret_labels
    annotations = local.cluster_secret_annotations
  }

  type = "Opaque"

  data = {
    # ArgoCD's required cluster-Secret fields.
    name   = var.cluster_name
    server = "https://kubernetes.default.svc"
    # `config` is reserved for connection metadata only (TLS, exec auth,
    # bearer tokens). Per-cluster template values live on the Secret's
    # annotations — see cluster_secret_annotations above.
    config = jsonencode({
      tlsClientConfig = {
        insecure = false
      }
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
      namespace = var.argocd_namespace
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
        namespace = var.argocd_namespace
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
