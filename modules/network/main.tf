locals {
  azs_count = length(var.azs)

  # Subnet CIDRs derived from the VPC CIDR via cidrsubnet():
  # /20 subnets carved from the /16. Six subnets total at 2 AZs (public/private/intra × 2)
  # leaves the upper half of the VPC free for future tiers.
  public_subnets  = { for idx, az in var.azs : az => cidrsubnet(var.cidr_block, 4, idx) }
  private_subnets = { for idx, az in var.azs : az => cidrsubnet(var.cidr_block, 4, idx + local.azs_count) }
  intra_subnets   = { for idx, az in var.azs : az => cidrsubnet(var.cidr_block, 4, idx + 2 * local.azs_count) }
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.name_prefix
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.name_prefix
  }
}

# Public subnets — internet-facing; load balancers and NAT gateways live here.
# kubernetes.io/role/elb tag lets the AWS Load Balancer Controller discover them
# for internet-facing Service/Ingress objects.
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.name_prefix}-public-${each.key}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private subnets — outbound via NAT, not reachable from the internet.
# EKS nodes and pods live here. internal-elb tag enables internal LB discovery.
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name                              = "${var.name_prefix}-private-${each.key}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Intra subnets — no default route. Resources here can talk to other resources
# inside the VPC but cannot reach the internet in either direction. RDS Aurora
# and ElastiCache go here so a misconfiguration cannot expose them outbound.
resource "aws_subnet" "intra" {
  for_each = local.intra_subnets

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "${var.name_prefix}-intra-${each.key}"
    Tier = "intra"
  }
}

# NAT — one per AZ so an AZ outage doesn't take down egress for the others.
resource "aws_eip" "nat" {
  for_each = aws_subnet.public

  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-${each.key}"
  }
}

resource "aws_nat_gateway" "main" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  tags = {
    Name = "${var.name_prefix}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public route table — single shared, default via IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-public"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private route tables — one per AZ, default via that AZ's NAT.
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-private-${each.key}"
  }
}

resource "aws_route" "private_default" {
  for_each = aws_subnet.private

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# Intra route table — shared, no default route. Only the implicit local route exists.
resource "aws_route_table" "intra" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-intra"
  }
}

resource "aws_route_table_association" "intra" {
  for_each = aws_subnet.intra

  subnet_id      = each.value.id
  route_table_id = aws_route_table.intra.id
}

# Gateway endpoints — free, no ENIs. Attached to every route table that may
# carry S3/DynamoDB traffic so private and intra workloads reach those services
# over the AWS backbone instead of via NAT (or not at all, in intra's case).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id, aws_route_table.intra.id],
    [for rt in aws_route_table.private : rt.id],
  )

  tags = {
    Name = "${var.name_prefix}-s3"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id, aws_route_table.intra.id],
    [for rt in aws_route_table.private : rt.id],
  )

  tags = {
    Name = "${var.name_prefix}-dynamodb"
  }
}
