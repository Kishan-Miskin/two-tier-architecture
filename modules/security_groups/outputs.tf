# ============================================================
# FILE: terraform-2tier-aws/modules/security_groups/outputs.tf
# ============================================================

output "alb_sg_id"    { value = aws_security_group.alb.id }
output "ec2_sg_id"    { value = aws_security_group.ec2.id }
output "bastion_sg_id" { value = aws_security_group.bastion.id }
output "rds_sg_id"    { value = aws_security_group.rds.id }
