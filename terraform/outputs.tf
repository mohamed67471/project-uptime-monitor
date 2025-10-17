output "ecs_cluster" {
  value = module.ecs.cluster_name
}

output "app_url" {
  value = "https://${var.domain_name}"
}

output "db_endpoint" {
  value     = module.rds.db_endpoint
  sensitive = true
}

output "alb_dns" {
  value = module.alb.alb_dns_name
}
