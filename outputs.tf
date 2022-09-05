output "vpc_id" {
  value = aws_vpc.global.id
}

output "rds_hostname" {
  value = aws_db_instance.global.address
}

output "rds_username" {
  value = aws_db_instance.global.username
}

output "api_key" {
  value     = aws_api_gateway_api_key.promotion_code.value
  sensitive = true
}

output "db_password" {
  value       = aws_db_instance.global.password
  description = "The password for logging in to the database."
  sensitive   = true
}
