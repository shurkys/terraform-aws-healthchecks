output "url" {
  description = "URL of Healthchecks"
  value       = local.healthchecks_url
}

################################################################################
# Load Balancer
################################################################################

output "alb" {
  description = "ALB created and all of its associated outputs"
  value       = module.alb
}

################################################################################
# ECS
################################################################################

output "cluster" {
  description = "ECS cluster created and all of its associated outputs"
  value       = module.ecs_cluster
}

output "service" {
  description = "ECS service created and all of its associated outputs"
  value       = module.ecs_service
}
