# ============================================================
# FILE: terraform-2tier-aws/modules/rds/outputs.tf
# ============================================================
output "rds_endpoint" {
  value     = aws_db_instance.mysql.endpoint
  sensitive = true
}

output "rds_port" {
  value = aws_db_instance.mysql.port
}

output "db_host" {
  description = "Hostname only — no port suffix"
  value       = aws_db_instance.mysql.address
  sensitive   = true
}

output "db_name" {
  value = aws_db_instance.mysql.db_name
}

output "db_username" {
  value = aws_db_instance.mysql.username
}
