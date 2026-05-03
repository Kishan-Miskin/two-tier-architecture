# ============================================================
# FILE: terraform-2tier-aws/modules/ec2/main.tf
# PURPOSE: Launch Template, Auto Scaling Group, CloudWatch alarms, Bastion host
# ============================================================

# ── IAM Role for EC2 (SSM Session Manager access) ────────────
resource "aws_iam_role" "ec2_role" {
  name = "${var.project}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ── Launch Template ───────────────────────────────────────────
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project}-${var.environment}-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [var.ec2_sg_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # Reads scripts/user_data.sh from the root of the project
  user_data = base64encode(file(var.user_data_path))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project}-${var.environment}-web"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Auto Scaling Group ────────────────────────────────────────
resource "aws_autoscaling_group" "web" {
  name                = "${var.project}-${var.environment}-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]
  health_check_type   = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-web-asg"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── ASG Scale-Out Policy (CPU > 70%) ─────────────────────────
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out when average CPU > 70% for 4 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

# ── ASG Scale-In Policy (CPU < 30%) ──────────────────────────
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.project}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project}-${var.environment}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale in when average CPU < 30% for 4 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

# ── Bastion Host ──────────────────────────────────────────────
resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  tags = {
    Name        = "${var.project}-${var.environment}-bastion"
    Environment = var.environment
  }
}
