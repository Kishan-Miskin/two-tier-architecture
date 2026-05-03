# ============================================================
# FILE: terraform-2tier-aws/modules/rds/main.tf
# PURPOSE: RDS MySQL 8.0 instance + DB subnet group
# ============================================================

# ── DB Subnet Group ───────────────────────────────────────────
# RDS requires subnets in at least 2 AZs
resource "aws_db_subnet_group" "main" {
  name        = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "Private subnets for RDS no public access"

  tags = {
    Name        = "${var.project}-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# ── RDS MySQL 8.0 Instance ────────────────────────────────────
resource "aws_db_instance" "mysql" {
  identifier              = "${var.project}-${var.environment}-mysql"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  storage_type            = "gp2"
  storage_encrypted       = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  multi_az               = false   # set true for prod HA
  publicly_accessible    = false   # never expose RDS to internet
  skip_final_snapshot    = true    # set false in prod (keeps a backup on destroy)
  deletion_protection    = false   # set true in prod

  backup_retention_period = 0      # days
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  tags = {
    Name        = "${var.project}-${var.environment}-mysql"
    Environment = var.environment
  }
}
