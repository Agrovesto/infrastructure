output "vpc_id" {
  value = aws_vpc.this.id
}
output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}
output "app_subnet_ids" {
  value = [for s in aws_subnet.app : s.id]
}
output "database_subnet_ids" {
  value = [for s in aws_subnet.database : s.id]
}
output "topology" {
  description = "Non-secret topology for operators and offline plan contracts."
  value = {
    nat_gateways       = length(aws_nat_gateway.this)
    public_subnets     = length(aws_subnet.public)
    app_subnets        = length(aws_subnet.app)
    database_subnets   = length(aws_subnet.database)
    isolated_db_routes = aws_route_table.database.route
  }
}
