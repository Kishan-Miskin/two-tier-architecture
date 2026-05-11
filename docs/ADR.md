# Architecture Decision Records (ADR)

Three key decisions made while designing this 2-tier infrastructure.

---

## ADR-001: Use a NAT Gateway instead of NAT Instances

**Date:** 2024-01-01  
**Status:** Accepted

### Context
Private EC2 instances need outbound internet access (to pull package updates, reach AWS APIs) but must never accept inbound connections from the internet. Two AWS options exist: NAT Gateway (managed) and NAT Instance (self-managed EC2).

### Decision
Use **AWS NAT Gateway** in the first public subnet.

### Rationale
| Factor | NAT Gateway | NAT Instance |
|--------|-------------|--------------|
| Management overhead | None (AWS-managed) | Requires patching, HA setup |
| Availability | Built-in redundancy | Single point of failure unless you run 2 |
| Throughput | Up to 100 Gbps | Limited by instance type |
| Cost | ~$0.045/hr + data | Cheaper for very low traffic |

For a two-tier web app expected to scale, the operational simplicity outweighs the modest cost premium. NAT Instances require disabling source/destination checks, managing HA yourself, and keeping the OS patched — toil that isn't justified here.

### Consequences
- Additional cost of ~$32/month for the NAT Gateway at rest
- Simpler operations, no single point of failure in the egress path

---

## ADR-002: Place the Auto Scaling Group in Private Subnets

**Date:** 2024-01-01  
**Status:** Accepted

### Context
Web-tier EC2 instances could be placed in public subnets (accessible directly) or private subnets (accessible only via the ALB).

### Decision
Deploy all ASG instances in **private subnets**. Only the ALB and Bastion host are in public subnets.

### Rationale
Defence-in-depth: even if a security group misconfiguration occurs, instances in private subnets have no public IP and cannot be directly reached from the internet. The attack surface is minimised to the ALB (port 80 only) and the Bastion (your IP only).

This also follows the AWS Well-Architected Framework's Security Pillar recommendation: "reduce your exposure to the internet — use private subnets for back-end resources."

A Bastion host in a public subnet provides controlled SSH access when direct instance access is genuinely needed, without exposing every EC2 to the internet.

### Consequences
- All legitimate web traffic enters through the ALB — a clean, auditable ingress point
- Engineers SSH via the Bastion (one extra hop), which is standard ops practice
- NAT Gateway is required for outbound internet from the private tier (see ADR-001)

---

## ADR-003: Use RDS Multi-AZ=false for Dev, with a clear production upgrade path

**Date:** 2024-01-01  
**Status:** Accepted

### Context
Amazon RDS MySQL offers a Multi-AZ deployment mode that automatically provisions a synchronous standby replica in a different AZ. This eliminates the DB as a single point of failure but doubles RDS cost.

### Decision
Set `multi_az = false` for the default (`dev`) environment. Add inline comments and variable defaults that make enabling it trivial for production.

### Rationale
For a development/demo environment the cost saving (~50% on RDS) is significant and availability SLAs are not contractually required. Forcing Multi-AZ on dev also complicates teardowns and increases `terraform apply` time.

The code is structured so that promoting to production requires changing a single variable:
```hcl
# In terraform.tfvars for prod:
# (extend variables.tf to expose this, or hard-code in rds/main.tf)
multi_az = true
```

Key prod settings already noted as comments in `modules/rds/main.tf`:
- `multi_az = true`
- `skip_final_snapshot = false`
- `deletion_protection = true`

### Consequences
- Dev environment has a single-AZ RDS — acceptable for non-critical workloads
- Promoting to prod requires a one-line change + a small maintenance window for AWS to provision the standby
- Cost is kept low during development and demonstration phases
