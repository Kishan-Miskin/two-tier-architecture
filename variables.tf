# ============================================================
# FILE: terraform-2tier-aws/variables.tf
# PURPOSE: All input variable definitions for the root module
# ============================================================

# ── General ──────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used as a prefix for all resource names"
  type        = string
  default     = "2tier"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

# ── Networking ───────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "bastion_ingress_cidr" {
  description = "Your public IP in CIDR notation (e.g. 203.0.113.10/32) — restricts SSH to Bastion"
  type        = string
  # No default: must be set in terraform.tfvars
}

# ── EC2 / ASG ────────────────────────────────────────────────
variable "key_pair_name" {
  description = "Name of the existing EC2 Key Pair for SSH access"
  type        = string
  # No default: must be set in terraform.tfvars
}

variable "instance_type" {
  description = "EC2 instance type for the web tier"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for the web-tier EC2 instances (Amazon Linux 2023 recommended)"
  type        = string
  default     = "ami-0c02fb55956c7d316" # Amazon Linux 2023 us-east-1 — update per region
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

# ── RDS ──────────────────────────────────────────────────────
variable "db_name" {
  description = "Name of the MySQL database to create"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for the RDS instance — keep this out of version control!"
  type        = string
  sensitive   = true
  # No default: must be set in terraform.tfvars
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for the RDS instance (GB)"
  type        = number
  default     = 20
}
