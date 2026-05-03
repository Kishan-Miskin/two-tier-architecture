# ============================================================
# FILE: terraform-2tier-aws/modules/vpc/variables.tf
# ============================================================

variable "project"         { type = string }
variable "environment"     { type = string }
variable "vpc_cidr"        { type = string }
variable "public_subnets"  { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "azs"             { type = list(string) }
