output "vpc_id" {
  description = "The VPC ID."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The VPC CIDR block."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, keyed by AZ."
  value       = { for az, s in aws_subnet.public : az => s.id }
}

output "private_subnet_ids" {
  description = "Private subnet IDs, keyed by AZ. EKS nodes and pod ENIs go here."
  value       = { for az, s in aws_subnet.private : az => s.id }
}

output "intra_subnet_ids" {
  description = "Intra subnet IDs, keyed by AZ. Resources here have no default route — RDS Aurora and ElastiCache go here."
  value       = { for az, s in aws_subnet.intra : az => s.id }
}

output "nat_gateway_public_ips" {
  description = "Elastic IPs of the NAT gateways, keyed by AZ."
  value       = { for az, e in aws_eip.nat : az => e.public_ip }
}

output "private_route_table_ids" {
  description = "Private route table IDs, keyed by AZ. Future interface VPC endpoints attach to these so private workloads reach AWS APIs without traversing NAT."
  value       = { for az, rt in aws_route_table.private : az => rt.id }
}

output "intra_route_table_id" {
  description = "Intra route table ID. Future Gateway endpoints destined only for intra workloads can attach here."
  value       = aws_route_table.intra.id
}
