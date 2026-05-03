# ============================================================
# FILE: terraform-2tier-aws/modules/alb/main.tf
# PURPOSE: Application Load Balancer, Target Group, HTTP Listener
# ============================================================

# ── Application Load Balancer ─────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false          # internet-facing
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false  # set true in prod

  tags = {
    Name        = "${var.project}-${var.environment}-alb"
    Environment = var.environment
  }
}

# ── Target Group (points at EC2 instances on port 80) ─────────
resource "aws_lb_target_group" "web" {
  name        = "${var.project}-${var.environment}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = { Name = "${var.project}-${var.environment}-tg" }
}

# ── HTTP Listener ─────────────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
