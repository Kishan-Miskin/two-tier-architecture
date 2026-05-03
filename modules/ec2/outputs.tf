# ============================================================
# FILE: terraform-2tier-aws/modules/ec2/outputs.tf
# ============================================================

output "bastion_public_ip"  { value = aws_instance.bastion.public_ip }
output "asg_name"           { value = aws_autoscaling_group.web.name }
output "launch_template_id" { value = aws_launch_template.web.id }
