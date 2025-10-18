terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-uptime-monitor-london"
    key            = "uptime-monitor/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
}

# VPC and networking
module "vpc" {
  source = "./modules/vpc"

  name_prefix           = local.name_prefix
  vpc_cidr              = var.vpc_cidr
  availability_zones    = local.azs
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
}

# Security groups for ALB, ECS, and RDS
module "security_groups" {
  source      = "./modules/security_groups"
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
}

# MySQL database
module "rds" {
  source = "./modules/rds"

  name_prefix             = local.name_prefix
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  database_name           = var.database_name
  master_username         = var.database_username
  master_password         = var.database_password
  db_subnet_group_name  = module.vpc.db_subnet_group_name
  vpc_security_group_ids  = [module.security_groups.rds_sg_id]
  multi_az                = false
  backup_retention_period = 7
}

# Store sensitive values in Secrets Manager
module "secrets" {
  source      = "./modules/secrets"
  name_prefix = local.name_prefix

  secrets = {
    db_password = var.database_password
    app_key     = var.app_key
  }
}

# Application load balancer
module "alb" {
  source = "./modules/alb"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.alb_sg_id]
  certificate_arn    = var.acm_certificate_arn
}

# ECS Fargate cluster
module "ecs" {
  source = "./modules/ecs"

  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_ids   = [module.security_groups.ecs_sg_id]
  alb_target_group_arn = module.alb.target_group_arn
  container_image      = var.container_image
  container_port       = 9000
  cpu                  = var.ecs_task_cpu
  memory               = var.ecs_task_memory
  desired_count        = var.ecs_desired_count
  log_retention_days   = 30

  environment_variables = {
    APP_NAME    = "Uptime Monitor"
    APP_ENV     = var.environment
    APP_DEBUG   = "false"
    APP_URL     = "https://${var.domain_name}"
    ASSET_URL   = "https://${var.domain_name}"
    FORCE_HTTPS = "true"
    
    # Database
    DB_CONNECTION = "mysql"
    DB_HOST       = module.rds.db_endpoint
    DB_PORT       = "3306"
    DB_DATABASE   = var.database_name
    DB_USERNAME   = var.database_username
    
    # Logging
    LOG_CHANNEL = "stderr"
    LOG_LEVEL   = "debug"
    
    # Cache and Session
    CACHE_DRIVER     = "file"
    SESSION_DRIVER   = "file"
    SESSION_LIFETIME = "120"
    
    # Queue
    QUEUE_CONNECTION = "sync"
    
    # Mail
    MAIL_MAILER = "smtp"
    MAIL_HOST   = "localhost"
    MAIL_PORT   = "1025"
  }

  secrets = {
    APP_KEY     = module.secrets.secret_arns["app_key"]
    DB_PASSWORD = module.secrets.secret_arns["db_password"]
  }
}

# DNS record pointing towards alb
module "route53" {
  source = "./modules/route53"

  domain_name    = var.domain_name
  alb_dns_name   = module.alb.alb_dns_name
  alb_zone_id    = module.alb.alb_zone_id
  hosted_zone_id = var.route53_hosted_zone_id
}

# CloudWatch monitoring and alarms
module "monitoring" {
  source = "./modules/monitoring"

  name_prefix             = local.name_prefix
  ecs_cluster_name        = module.ecs.cluster_name
  ecs_service_name        = module.ecs.service_name
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  rds_instance_id         = module.rds.db_instance_id
  target_group_arn        = module.alb.target_group_arn
  aws_region              = var.aws_region
}
