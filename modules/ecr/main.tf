# Private container registry for the demo application image.
#
# One repository for the whole account: the image is an environment-agnostic
# artifact — built once by the app repo's CI, promoted across environments by
# tag. In a multi-account split this would live in a shared tooling account
# with cross-account pull; single-account here keeps that a config-only move,
# same story as the GitHub OIDC provider singleton.
#
# The repository name deliberately carries no environment segment.

resource "aws_ecr_repository" "demo_app" {
  name = "${var.project}/demo-app"

  # A tag can never be repointed, so the tag pinned in the gitops repo IS the
  # image that passed the pipeline's scans. CI pushes one unique git-SHA tag
  # per merge; there is no moving `latest`.
  image_tag_mutability = "IMMUTABLE"

  # Registry-side verification only — the gating scan is Trivy in the app
  # pipeline, which fails the build on HIGH/CRITICAL before anything is
  # pushed. Enhanced scanning (Inspector) was considered and deferred: it
  # bills continuously against a repository that persists across teardowns.
  image_scanning_configuration {
    scan_on_push = true
  }

  # AES256 rather than a customer-managed key — a deliberate deviation from
  # the CMK-everywhere pattern. Every other module's CMK protects confidential
  # data; these images are public base layers plus open-source demo code, and
  # this is the one resource that persists 24/7, so a CMK would be the
  # project's only standing key cost for no confidentiality gain.
  encryption_configuration {
    encryption_type = "AES256"
  }

  # The Terragrunt unit sets prevent_destroy so routine `run --all destroy`
  # skips the registry. force_delete is for the final project teardown, when
  # that guard is lifted: ECR refuses to delete a non-empty repository
  # otherwise.
  force_delete = true
}

# Storage hygiene: untagged manifests (multi-arch leftovers, buildkit cache
# pushes) are waste after a day, and the tag history has no value beyond a
# rollback window. Rules evaluate lowest rulePriority first.
resource "aws_ecr_lifecycle_policy" "demo_app" {
  repository = aws_ecr_repository.demo_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after one day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the most recent 10 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 10
        }
        action = { type = "expire" }
      },
    ]
  })
}
