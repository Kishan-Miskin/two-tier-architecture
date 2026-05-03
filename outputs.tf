# ============================================================
# FILE: terraform-2tier-aws/outputs.tf
# PURPOSE: Prints the most useful endpoints after `terraform apply`
# ============================================================

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer — open in your browser"
  value       = "http://${module.alb.alb_dns_name}"
}

output "bastion_public_ip" {
  description = "Public IP of the Bastion host — SSH via: ssh -i <key>.pem ec2-user@<IP>"
  value       = module.ec2.bastion_public_ip
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint — use this in your app's DB connection string"
  value       = module.rds.rds_endpoint
  sensitive   = true
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (web + DB tier)"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB + Bastion)"
  value       = module.vpc.public_subnet_ids
}
