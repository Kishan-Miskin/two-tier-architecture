# ============================================================
# FILE: terraform-2tier-aws/modules/security_groups/main.tf
# PURPOSE: Four security groups — ALB, EC2, Bastion, RDS
# ============================================================

# ── ALB Security Group ────────────────────────────────────────
# Allows HTTP (80) from the public internet
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "Allow HTTP inbound from the internet to the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.environment}-alb-sg" }
}

# ── EC2 / Web-Tier Security Group ────────────────────────────
# Accepts traffic ONLY from the ALB (port 80) and Bastion (SSH 22)
resource "aws_security_group" "ec2" {
  name        = "${var.project}-${var.environment}-ec2-sg"
  description = "Allow HTTP from ALB and SSH from Bastion only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "SSH from Bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "All outbound (for yum/apt updates via NAT GW)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.environment}-ec2-sg" }
}

# ── Bastion Security Group ────────────────────────────────────
# SSH only from your IP (bastion_ingress_cidr in tfvars)
resource "aws_security_group" "bastion" {
  name        = "${var.project}-${var.environment}-bastion-sg"
  description = "Allow SSH only from operator IP"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from operator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_ingress_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.environment}-bastion-sg" }
}

# ── RDS Security Group ────────────────────────────────────────
# MySQL (3306) only from the EC2 web tier
resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "Allow MySQL only from web-tier EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from web tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.environment}-rds-sg" }
}
