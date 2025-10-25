# 🚀 Uptime Monitor  

[![AWS ECS](https://img.shields.io/badge/AWS-ECS-orange?logo=amazon-aws)](https://aws.amazon.com/ecs/)  [![Infrastructure](https://img.shields.io/badge/Infrastructure-Terraform-purple?logo=terraform)](https://www.terraform.io/)  [![Container](https://img.shields.io/badge/Container-Docker-blue?logo=docker)](https://www.docker.com/) [![Framework](https://img.shields.io/badge/Framework-Laravel-red?logo=laravel)](https://laravel.com/)  

A **production-grade Laravel application** for monitoring website uptime and performance — fully deployed on **AWS** using **Infrastructure as Code (Terraform)**, **S3 with DynamoDB state locking**, and **automated CI/CD pipelines**.  

Built with **reliability, scalability, and security** in mind.  

---

## ✨ Features  

- **Website Monitoring** – Track uptime and response times across multiple domains  
- **Multi-Vendor Support** – Group and organize sites per client/vendor  
- **Real-Time Checks** – Manual and automated uptime tests  
- **User Management** – Role-based authentication system  
- **High Availability** – Deployed across multiple availability zones  
- **Auto Scaling** – ECS Fargate handles container scaling automatically  
- **SSL/TLS Security** – Managed via AWS ACM certificates  
- **Centralized Monitoring** – CloudWatch dashboards and alarms  
- **State Locking** – Terraform backend uses **S3 with DynamoDB** for safe, concurrent state management  
- **Pre-Commit Hooks** – Automated linting and validation before commits to maintain code quality  

---

## 🏗️ Architecture  

<img width="777" height="1205" alt="uptimemonitor drawio" src="https://github.com/user-attachments/assets/188f01d2-5b3e-4bbd-b7ac-2b47e3dc134b" />




### Infrastructure Components

- **VPC:** Custom VPC (10.0.0.0/16) across 2 AZs (eu-west-2a, eu-west-2b)  
- **Subnets:** Public (ALB/NAT), Private (ECS), and Database subnets (RDS)  
- **NAT Gateways:** High-availability configuration  
- **ALB:** Internet-facing with HTTPS ([ACM Certificates](https://aws.amazon.com/certificate-manager/))  
- **ECS Fargate:** Serverless container orchestration  
- **RDS MySQL:** Managed database with automated backups  
- **ECR:** Private image repository for CI/CD pipelines  
- **CloudWatch:** Logs, metrics, alarms, and dashboards  

---

## 🌐 Live Demo

https://github.com/user-attachments/assets/9374cefb-e5d8-4d0a-be2e-6f5a50effaff





<img width="940" height="492" alt="image" src="https://github.com/user-attachments/assets/8e0ba533-77b9-4055-88f1-9f59a61e0240" />
<img width="940" height="467" alt="image" src="https://github.com/user-attachments/assets/c9c3ee5a-c81e-4f50-b711-7a32e0b53f7f" />



**Live Application URL:** [https://tm.mohamed-uptime.com](https://tm.mohamed-uptime.com)

**Default Login Credentials:**
Email: admin@example.net
Password: password

## 🛠️ Tech Stack

### Application
- **Framework:** Laravel 11 (PHP 8.2)  
- **Database:** MySQL 8.0  
- **Frontend:** Blade + Tailwind CSS  
- **Testing:** PHPUnit + BrowserKit  

### Infrastructure
- **Cloud Provider:** [AWS](https://aws.amazon.com/)  
- **IaC:** [Terraform](https://www.terraform.io/) (S3 + DynamoDB backend for state locking)  
- **Containers:** [Docker](https://www.docker.com/) (multi-stage builds)  
- **Orchestration:** [AWS ECS Fargate](https://aws.amazon.com/fargate/)  
- **Load Balancer:** [Application Load Balancer](https://aws.amazon.com/elasticloadbalancing/)  
- **Database:** [RDS MySQL](https://aws.amazon.com/rds/mysql/)  
- **Storage:** [EBS gp3](https://aws.amazon.com/ebs/)  

### CI/CD
- **Pipeline:** [GitHub Actions](https://docs.github.com/en/actions)  
- **Authentication:** OIDC (no static credentials)  
- **Security:** Trivy vulnerability scanning  
- **Registry:** [Amazon ECR](https://aws.amazon.com/ecr/)  
- **Pre-Commit Hooks:** Enforced formatting, linting, and security checks  

---

## 🚀 Infrastructure Setup

### Clone Repository
```bash
git clone https://github.com/mohamed67471/project-uptime-monitor.git
cd project-uptime-monitor/uptime-monitor

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

## Access via AWS CloudWatch
CloudWatch Alarms  
Pre-configured alarms:

⚠️ ECS CPU > 80%  
⚠️ ECS Memory > 80%  
⚠️ ALB 5xx errors > 10/minute  
⚠️ Unhealthy targets detected  
⚠️ RDS CPU > 80%  
⚠️ RDS free storage < 2GB  
```
aws logs tail /ecs/uptime-monitor-production --follow --region eu-west-2

## ci/cd and trivy scan 
<img width="940" height="463" alt="image" src="https://github.com/user-attachments/assets/b8ed37e0-5f32-47a2-b0c4-722170bc1077" />
<img width="940" height="451" alt="image" src="https://github.com/user-attachments/assets/a2e343db-7810-4395-a781-129cb331f1da" />
<img width="940" height="612" alt="image" src="https://github.com/user-attachments/assets/2dffb47f-bc7d-4b8a-a863-0838bd4e010a" />

## cloud watch dashboard 
<img width="939" height="401" alt="image" src="https://github.com/user-attachments/assets/bdf47bf3-3d48-4bf0-b5dc-9e53ebcf23e4" />
<img width="938" height="403" alt="image" src="https://github.com/user-attachments/assets/87acc915-36e8-4e5d-98eb-11bf50f97884" />


🔒 Security  
Infrastructure

- Private subnets (no public ECS/RDS access)  
- IAM least-privilege roles  
- Secrets stored in AWS Secrets Manager  
- S3 + DynamoDB for state locking  
- SSL/TLS enforced via ACM  
- OIDC authentication for CI/CD (no static keys)  

🧭 Future Improvements

✅ Add WAF protection  
✅ RDS across multiple AZs for backup  
✅ SNS Integration: Email/SMS notifications when sites go down  
✅ Slack/Discord Webhooks: Real-time alerts to team channels  









