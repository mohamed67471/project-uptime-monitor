variable "project_name" {
  type    = string
  default = "uptime-monitor"
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "vpc_cidr" {
  type = string
}

variable "environment" {
  type    = string
  default = "production"
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "database_name" {
  type = string
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "container_image" {
  type = string
}

variable "database_subnet_cidrs" {
  type = list(string)
}

variable "ecs_task_cpu" {
  type = string
}

variable "database_username" {
  type = string
}

variable "ecs_task_memory" {
  type = string
}

variable "database_password" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type = string
}

variable "ecs_desired_count" {
  type = number
}

variable "app_key" {
  type      = string
  sensitive = true
}

variable "acm_certificate_arn" {
  type = string
}

variable "route53_hosted_zone_id" {
  type = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
}
