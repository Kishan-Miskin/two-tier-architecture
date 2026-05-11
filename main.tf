# ============================================================
# FILE: terraform-2tier-aws/main.tf
# PURPOSE: Root entry point — calls all child modules
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment AFTER running backend-setup/main.tf once
  # backend "s3" {
  #   bucket         = "your-tf-state-bucket-name"     # ← replace
  #   key            = "2tier/terraform.tfstate"
  #   region         = "us-east-1"                     # ← replace if needed
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

# ── VPC ──────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project          = var.project
  environment      = var.environment
  vpc_cidr         = var.vpc_cidr
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  azs              = var.azs
}

# ── Security Groups ──────────────────────────────────────────
module "security_groups" {
  source = "./modules/security_groups"

  project        = var.project
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  bastion_ingress_cidr = var.bastion_ingress_cidr
}

# ── ALB ──────────────────────────────────────────────────────
module "alb" {
  source = "./modules/alb"

  project          = var.project
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id        = module.security_groups.alb_sg_id
}

# ── EC2 / ASG ────────────────────────────────────────────────
module "ec2" {
  source = "./modules/ec2"

  project              = var.project
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_ids    = module.vpc.public_subnet_ids
  ec2_sg_id            = module.security_groups.ec2_sg_id
  bastion_sg_id        = module.security_groups.bastion_sg_id
  target_group_arn     = module.alb.target_group_arn
  key_pair_name        = var.key_pair_name
  instance_type        = var.instance_type
  ami_id               = var.ami_id
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity
  user_data_path       = "${path.root}/scripts/user_data.sh"
  db_host     = module.rds.db_host      # .address — host only, no :3306
  db_name     = module.rds.db_name
  db_username = module.rds.db_username
  db_password = var.db_password# from terraform.tfvars
}

# ── RDS ──────────────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  project             = var.project
  environment         = var.environment
  private_subnet_ids  = module.vpc.private_subnet_ids
  rds_sg_id           = module.security_groups.rds_sg_id
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  db_instance_class   = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
}
