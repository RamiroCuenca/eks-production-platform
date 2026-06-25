# Secrets Manager interface VPC endpoint.
#
# Realizes the journaled "interface endpoints land with their consumer"
# commitment: this is the first module whose workloads fetch secrets. With
# private DNS enabled, secretsmanager.<region>.amazonaws.com resolves to these
# ENIs automatically (no SDK or env change), so the ASCP provider's
# GetSecretValue response stays on the AWS backbone instead of crossing NAT and
# the public internet, and NAT data-processing charges on secret fetches drop.
#
# The STS endpoint is deliberately NOT added here — IRSA's
# AssumeRoleWithWebIdentity works over NAT, the regional-STS posture is a larger
# change, and the secret value is the sensitive payload this endpoint already
# protects. Documented as the next endpoint to add.
resource "aws_security_group" "secretsmanager_endpoint" {
  name        = "${var.name_prefix}-secretsmanager-endpoint"
  description = "HTTPS from the VPC to the Secrets Manager interface endpoint"
  vpc_id      = var.vpc_id

  # No egress rule: an interface-endpoint ENI never initiates connections, it
  # only answers inbound 443. Security groups are stateful, so reply traffic on
  # established connections needs no egress allow. Leaving egress unmanaged
  # yields an ingress-only group — the tighter posture for an endpoint.

  tags = { Name = "${var.name_prefix}-secretsmanager-endpoint" }
}

# Ingress 443 from the VPC CIDR rather than a specific SG reference: under
# Cilium ENI IPAM, pod egress originates from Cilium-assigned ENIs whose SG
# association is not a stable Terraform reference. A single-port allow to a
# single AWS API, still IAM-gated, is the robust low-coupling choice.
resource "aws_vpc_security_group_ingress_rule" "secretsmanager_https" {
  security_group_id = aws_security_group.secretsmanager_endpoint.id
  description       = "HTTPS from in-VPC workloads"
  cidr_ipv4         = var.vpc_cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(var.private_subnet_ids)
  security_group_ids  = [aws_security_group.secretsmanager_endpoint.id]
  private_dns_enabled = true

  tags = { Name = "${var.name_prefix}-secretsmanager" }
}
