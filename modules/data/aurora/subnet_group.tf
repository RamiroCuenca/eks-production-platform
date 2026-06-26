# Subnet group over the VPC's INTRA subnets — the subnets with no default route
# to a NAT or internet gateway. A managed database never needs to initiate
# outbound internet connections; placing it where no such route exists is
# defense-in-depth that even a misconfiguration cannot undo. RDS-managed
# password rotation is internal to the RDS service, so it works here without any
# outbound path of the cluster's own.
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-aurora"
  subnet_ids = values(var.intra_subnet_ids)

  tags = { Name = "${var.name_prefix}-aurora" }
}
