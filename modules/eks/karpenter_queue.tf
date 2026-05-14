# Karpenter interruption queue.
#
# AWS publishes a 2-minute warning to EventBridge when a spot instance is
# about to be reclaimed (and analogous events for health/rebalance). The
# Karpenter controller watches this SQS queue and gracefully drains the
# soon-to-die node so its pods reschedule before reclamation. Without the
# queue, spot reclamation surfaces as cold pod termination.
#
# The queue's ARN is consumed by the Karpenter Helm chart (in the gitops
# repo) via `settings.interruptionQueue`.

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${local.cluster_name}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = [
          "events.amazonaws.com",
          "sqs.amazonaws.com",
        ]
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# ---------- EventBridge → SQS routing ----------

locals {
  karpenter_event_rules = {
    spot_interrupt = {
      description = "Spot instance interruption warning (2-minute notice)."
      pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Spot Instance Interruption Warning"]
      }
    }
    rebalance = {
      description = "Spot rebalance recommendation — early signal before interruption."
      pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance Rebalance Recommendation"]
      }
    }
    state_change = {
      description = "EC2 instance state change — Karpenter reconciles node lifecycle from this."
      pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
      }
    }
    health_event = {
      description = "AWS Health scheduled events affecting EC2 instances."
      pattern = {
        source      = ["aws.health"]
        detail-type = ["AWS Health Event"]
      }
    }
  }
}

resource "aws_cloudwatch_event_rule" "karpenter" {
  for_each = local.karpenter_event_rules

  name          = "${local.cluster_name}-karpenter-${each.key}"
  description   = each.value.description
  event_pattern = jsonencode(each.value.pattern)
}

resource "aws_cloudwatch_event_target" "karpenter" {
  for_each = local.karpenter_event_rules

  rule      = aws_cloudwatch_event_rule.karpenter[each.key].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}
