# VPC flow logs — captures packet metadata for incident response and traffic
# analysis. CloudWatch destination integrates with the Loki/Grafana stack
# added in the observability phase.

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.name_prefix}/flow-logs"
  retention_in_days = var.flow_logs_retention_days
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name_prefix}-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name_prefix}-flow-logs"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
}
