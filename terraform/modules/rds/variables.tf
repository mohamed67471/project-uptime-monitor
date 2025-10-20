variable "name_prefix" {
  type = string
}

variable "engine_version" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "database_name" {
  type = string
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type      = string
  sensitive = true
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "multi_az" {
  type = bool
}

variable "backup_retention_period" {
  type = number
}

variable "db_subnet_group_name" {
  type        = string
  description = "Name of the DB subnet group from VPC module"
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Whether to skip final snapshot on deletion"
  default     = false
}