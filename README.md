# 2-Tier AWS Architecture — Terraform

A production-ready 2-tier infrastructure on AWS, provisioned entirely with Terraform modules.

---

## Architecture Diagram

```
                        ┌─────────────────────────────────────────────────────┐
                        │                    AWS VPC (10.0.0.0/16)            │
                        │                                                     │
  Internet              │  PUBLIC SUBNETS (10.0.1.0/24, 10.0.2.0/24)        │
  Users ──────────────► │  ┌──────────────┐     ┌────────────┐              │
        HTTP:80         │  │     ALB      │     │  Bastion   │◄── SSH (you) │
                        │  │ (multi-AZ)   │     │  Host      │              │
                        │  └──────┬───────┘     └────────────┘              │
                        │         │ HTTP:80                                  │
                        │  PRIVATE SUBNETS (10.0.11.0/24, 10.0.12.0/24)    │
                        │  ┌──────▼───────────────────┐                     │
                        │  │  Auto Scaling Group       │                     │
                        │  │  ┌──────────┐ ┌────────┐ │                     │
                        │  │  │ EC2 web  │ │ EC2 web│ │  (2–4 instances)   │
                        │  │  └────┬─────┘ └───┬────┘ │                     │
                        │  └───────┼────────────┼──────┘                     │
                        │          └─────┬───────┘  MySQL:3306               │
                        │         ┌──────▼──────────────┐                    │
                        │         │  RDS MySQL 8.0       │                    │
                        │         │  (private, encrypted)│                    │
                        │         └──────────────────────┘                    │
                        └─────────────────────────────────────────────────────┘
```

---

## Project Structure

```
terraform-2tier-aws/
├── main.tf              ← Entry point, calls all modules
├── variables.tf         ← All input variable definitions
├── outputs.tf           ← Prints ALB URL, Bastion IP, RDS endpoint
├── terraform.tfvars     ← YOUR values here (gitignored)
├── .gitignore
│
├── modules/
│   ├── vpc/             ← VPC, subnets, IGW, NAT GW, route tables
│   ├── security_groups/ ← ALB, EC2, Bastion, RDS security groups
│   ├── alb/             ← ALB, Target Group, HTTP Listener
│   ├── ec2/             ← Launch Template, ASG, CloudWatch alarms, Bastion
│   └── rds/             ← RDS MySQL 8.0, subnet group
│
├── scripts/
│   └── user_data.sh     ← Installs nginx, serves dark-themed status page
│
├── backend-setup/
│   └── main.tf          ← Run ONCE to create S3 + DynamoDB for remote state
│
└── docs/
    ├── README.md        ← This file
    └── ADR.md           ← Architecture Decision Records
```

---

## Prerequisites

| Tool      | Version |
|-----------|---------|
| Terraform | ≥ 1.5.0 |
| AWS CLI   | ≥ 2.x   |
| AWS credentials configured (`aws configure`) | — |

You also need:
- An **EC2 Key Pair** created in your target region
- Your **public IP address** (visit https://checkip.amazonaws.com)

---

## Deployment Steps

### Step 1 — Set up remote state (run once)

```bash
cd backend-setup
terraform init
terraform apply
# Note the state_bucket_name output value
```

### Step 2 — Enable the backend in root main.tf

Open `main.tf` and uncomment the `backend "s3"` block. Paste in the bucket name from Step 1.

```hcl
backend "s3" {
  bucket         = "2tier-tf-state-xxxxxxxx"  # ← from Step 1 output
  key            = "2tier/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

### Step 3 — Fill in terraform.tfvars

Open `terraform.tfvars` and replace all placeholder values:

```hcl
bastion_ingress_cidr = "YOUR_PUBLIC_IP/32"   # e.g. "203.0.113.10/32"
key_pair_name        = "my-keypair"
db_password          = "MySecurePass123"
```

### Step 4 — Deploy

```bash
cd ..               # back to terraform-2tier-aws root
terraform init
terraform plan
terraform apply
```

### Step 5 — Access your app

After apply completes, Terraform prints:

```
alb_dns_name   = "http://2tier-dev-alb-xxxxxxxxxx.us-east-1.elb.amazonaws.com"
bastion_public_ip = "x.x.x.x"
```

Open the ALB URL in your browser. You'll see the dark-themed status page with instance metadata.

### Step 6 — SSH to a web instance via Bastion

```bash
# Add key to agent
ssh-add ~/path/to/your-key.pem

# Jump through Bastion to a private EC2
ssh -J ec2-user@<BASTION_IP> ec2-user@<PRIVATE_EC2_IP>
```

---

## Tear Down

```bash
terraform destroy
```

This destroys all resources. The S3 state bucket is protected (`force_destroy = false`) — delete it manually from the console if needed.

---

## Security Notes

- RDS is in private subnets with no public access
- EC2 instances receive traffic only from the ALB
- Bastion SSH is restricted to your IP only
- All passwords are marked `sensitive` and excluded from logs
- State bucket has versioning + AES-256 encryption enabled
