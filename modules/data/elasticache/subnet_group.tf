# Subnet group over the VPC's INTRA subnets (no NAT/IGW route). A managed cache
# never needs to initiate outbound internet connections; placing it where no
# such route exists is defense-in-depth.
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name_prefix}-redis"
  subnet_ids = values(var.intra_subnet_ids)

  tags = { Name = "${var.name_prefix}-redis" }
}
