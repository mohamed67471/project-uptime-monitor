variable "name_prefix" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix for the ALB"
  type        = string
}
variable "rds_instance_id" {
  description = "RDS instance id for cloudwatch"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}
