# Agrovesto Infrastructure

Terraform-managed cloud infrastructure for **Agrovesto** — a digital agriculture ecosystem connecting smallholder farmers, cooperatives, traders, and financiers across Nigeria.

## About

Agrovesto builds the data and transactional infrastructure powering Africa's agricultural value chain. The platform (NomaOS) creates GPS-mapped digital farm profiles, enables commodity trading, and unlocks access to finance, inputs, and markets for 20,000+ smallholder farmers across multiple states.

This repository contains all infrastructure-as-code for our production and staging environments.

## Repository Structure
   ├── modules/
│ ├── network/ # VPC, subnets, security groups, NAT
│ ├── compute/ # EC2 / ECS / Lambda
│ ├── database/ # RDS, ElastiCache, S3
│ ├── data/ # Data pipelines, ETL, analytics
│ ├── api/ # API Gateway, ALB, WAF
│ └── monitoring/ # CloudWatch, logging, alerting
├── environments/
│ ├── dev/
│ ├── staging/
│ └── production/
├── scripts/
│ ├── bootstrap.sh
│ └── destroy.sh
└── .terraform.lock.hcl


## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform) ≥ 1.5
- AWS CLI (or your cloud provider's CLI)
- Required provider credentials configured

## Getting Started

# Clone
git clone git@github.com:agrovesto/infrastructure.git
cd infrastructure

# Initialize
terraform -chdir=environments/dev init

# Plan
terraform -chdir=environments/dev plan

# Apply
terraform -chdir=environments/dev apply   

Environments
Environment	Purpose
dev	Local development & testing
staging	Pre-production, integration testing
production	Live services

Conventions
One Terraform module per concern (networking, compute, data, etc.)
Each environment is a standalone root module that composes shared modules
State is stored remotely (S3 + DynamoDB locking)
All secrets managed via AWS Secrets Manager / SSM Parameter Store
Tagging: every resource tagged with Project=Agrovesto, Environment=<env>, ManagedBy=terraform
Contributing
Create a feature branch
Run terraform fmt and terraform validate
Open a PR with a clear description of the change
CI runs plan (no apply) on every PR

