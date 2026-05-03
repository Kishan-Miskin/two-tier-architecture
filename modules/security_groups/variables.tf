# ============================================================
# FILE: terraform-2tier-aws/modules/security_groups/variables.tf
# ============================================================

variable "project"              { type = string }
variable "environment"          { type = string }
variable "vpc_id"               { type = string }
variable "bastion_ingress_cidr" { type = string }
