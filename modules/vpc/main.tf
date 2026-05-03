# ============================================================
# FILE: terraform-2tier-aws/modules/vpc/main.tf
# PURPOSE: VPC, public/private subnets, IGW, NAT GW, route tables
# ============================================================

# ── VPC ──────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project}-${var.environment}-vpc"
    Environment = var.environment
    Project     = var.project
  }
}

# ── Public Subnets (ALB + Bastion) ───────────────────────────
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project}-${var.environment}-public-${var.azs[count.index]}"
    Environment = var.environment
    Tier        = "public"
  }
}

# ── Private Subnets (EC2 ASG + RDS) ──────────────────────────
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name        = "${var.project}-${var.environment}-private-${var.azs[count.index]}"
    Environment = var.environment
    Tier        = "private"
  }
}

# ── Internet Gateway ──────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project}-${var.environment}-igw"
    Project = var.project
  }
}

# ── Elastic IP for NAT Gateway ───────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "${var.project}-${var.environment}-nat-eip"
    Project = var.project
  }
}

# ── NAT Gateway (placed in first public subnet) ───────────────
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name    = "${var.project}-${var.environment}-nat-gw"
    Project = var.project
  }
}

# ── Public Route Table ────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project}-${var.environment}-public-rt"
    Project = var.project
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Table (routes outbound via NAT) ─────────────
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "${var.project}-${var.environment}-private-rt"
    Project = var.project
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
