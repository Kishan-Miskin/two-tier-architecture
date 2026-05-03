# ============================================================
# FILE: terraform-2tier-aws/modules/ec2/variables.tf
# ============================================================

variable "project"              { type = string }
variable "environment"          { type = string }
variable "vpc_id"               { type = string }
variable "private_subnet_ids"   { type = list(string) }
variable "public_subnet_ids"    { type = list(string) }
variable "ec2_sg_id"            { type = string }
variable "bastion_sg_id"        { type = string }
variable "target_group_arn"     { type = string }
variable "key_pair_name"        { type = string }
variable "instance_type"        { type = string }
variable "ami_id"               { type = string }
variable "asg_min_size"         { type = number }
variable "asg_max_size"         { type = number }
variable "asg_desired_capacity" { type = number }
variable "user_data_path"       { type = string }
