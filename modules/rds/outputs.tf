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
