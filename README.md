🚀 Uptime Monitor
https://img.shields.io/badge/AWS-ECS-orange
https://img.shields.io/badge/Infrastructure-Terraform-purple
https://img.shields.io/badge/Container-Docker-blue
https://img.shields.io/badge/Framework-Laravel-red

A production-grade Laravel application for monitoring website uptime and performance — fully deployed on AWS using Infrastructure as Code (Terraform), S3 with DynamoDB state locking, and automated CI/CD pipelines.

Built with reliability, scalability, and security in mind.

✨ Features

Website Monitoring – Track uptime and response times across multiple domains
Multi-Vendor Support – Group and organize sites per client/vendor
Real-Time Checks – Manual and automated uptime tests
User Management – Role-based authentication system
High Availability – Deployed across multiple availability zones
Auto Scaling – ECS Fargate handles container scaling automatically
SSL/TLS Security – Managed via AWS ACM certificates
Centralized Monitoring – CloudWatch dashboards and alarms
State Locking – Terraform backend uses S3 with DynamoDB for safe, concurrent state management
Pre-Commit Hooks – Automated linting and validation before commits to maintain code quality

🏗️ Architecture
High-Level Overview
Internet
   ↓
Route53 (tm.mohamed-uptime.com)
   ↓
Application Load Balancer (HTTPS)
   ↓
ECS Fargate Tasks (Private Subnets)
   ↓
RDS MySQL (Database Subnets)

Infrastructure Components

VPC: Custom VPC (10.0.0.0/16) across 2 AZs (eu-west-2a, eu-west-2b)

Subnets: Public (ALB/NAT), Private (ECS), and Database subnets (RDS)

NAT Gateways: High-availability configuration

ALB: Internet-facing with HTTPS (ACM certificates)

ECS Fargate: Serverless container orchestration

RDS MySQL: Managed database with automated backups

ECR: Private image repository for CI/CD pipelines

CloudWatch: Logs, metrics, alarms, and dashboards

🌐 Live Demo
<!-- [INSERT LIVE APPLICATION SCREENSHOT] -->
Live Application URL: https://tm.mohamed-uptime.com

Default Login Credentials:

Email: admin@example.net

Password: password
🛠️ Tech Stack

Application

Framework: Laravel 11 (PHP 8.2)

Database: MySQL 8.0

Frontend: Blade + Tailwind CSS

Testing: PHPUnit + BrowserKit

Infrastructure

Cloud Provider: AWS

IaC: Terraform (with S3 + DynamoDB backend for state locking)

Containers: Docker (multi-stage builds)

Orchestration: AWS ECS Fargate

Load Balancer: ALB

Database: RDS MySQL

Storage: EBS (gp3)

CI/CD

Pipeline: GitHub Actions

Authentication: OIDC (no static credentials)

Security: Trivy vulnerability scanning

Registry: Amazon ECR

Pre-Commit Hooks: Enforced formatting, linting, and security checks

🚀 Infrastructure Setup
# Clone repository
git clone https://github.com/mohamed67471/project-uptime-monitor.git
cd project-uptime-monitor/terraform

Configure Variables
cp terraform.tfvars.example terraform.tfvars
# Edit your variables (region, domain, database credentials, etc.)

Initialize and Apply
terraform init
terraform plan
terraform apply


Backend: Terraform state is stored in S3 with DynamoDB state locking to prevent concurrent changes.
Estimated time: ~10–15 minutes

💻 Local Development
Using Docker Compose
cp .env.example .env
php artisan key:generate

docker-compose up -d
docker-compose exec app php artisan migrate --seed


Visit → http://localhost:8000

Default credentials:
admin@example.net / password

🚢 Deployment
Automated (CI/CD)

Every push to main triggers:

✅ PHPUnit + static analysis

🛠 Docker image build & Trivy scan

🚀 ECS service update (zero-downtime deploy)

git add .
git commit -m "feat: new feature"
git push origin main

📊 Monitoring

Access via CloudWatch:

ECS CPU & memory usage

ALB response times and 5xx errors

RDS performance metrics

Application logs and alarms

aws logs tail /ecs/uptime-monitor-production --follow --region eu-west-2

🔒 Security

Infrastructure

Private subnets (no public ECS/RDS access)

IAM least-privilege roles

Secrets stored in AWS Secrets Manager

S3 + DynamoDB for state locking

SSL/TLS enforced via ACM

OIDC authentication for CI/CD (no static keys)

Application

CSRF, XSS, SQLi protection

HTTPS enforced

Passwords hashed (bcrypt)

Dependency scanning and Trivy reports

🧪 Testing
php artisan test --coverage
php artisan test --parallel