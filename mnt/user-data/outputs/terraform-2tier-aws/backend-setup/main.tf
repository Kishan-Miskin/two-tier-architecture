# ============================================================
# FILE: terraform-2tier-aws/backend-setup/main.tf
# PURPOSE: Run this ONCE before the main project.
#          Creates the S3 bucket + DynamoDB table used for
#          remote Terraform state storage and state locking.
#
# HOW TO USE:
#   cd backend-setup
#   terraform init
#   terraform apply
#
# After apply, copy the bucket name into the backend block
# inside the root main.tf and re-run `terraform init` there.
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "us-east-1"
}

variable "project" {
  default = "2tier"
}

# S3 bucket name must be globally unique — adjust the suffix if needed
locals {
  bucket_name = "${var.project}-tf-state-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# ── S3 Bucket for Terraform State ────────────────────────────
resource "aws_s3_bucket" "tf_state" {
  bucket        = local.bucket_name
  force_destroy = false   # protect state from accidental deletion

  tags = { Name = local.bucket_name, Project = var.project }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── DynamoDB Table for State Locking ─────────────────────────
resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = "terraform-state-lock", Project = var.project }
}

# ── Outputs ───────────────────────────────────────────────────
output "state_bucket_name" {
  value       = aws_s3_bucket.tf_state.bucket
  description = "Paste this bucket name into root main.tf backend block"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.tf_lock.name
}
