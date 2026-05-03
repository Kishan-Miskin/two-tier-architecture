# ============================================================
# FILE: terraform-2tier-aws/modules/alb/outputs.tf
# ============================================================

output "alb_dns_name"      { value = aws_lb.main.dns_name }
output "target_group_arn"  { value = aws_lb_target_group.web.arn }
