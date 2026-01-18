# ==============================================================================
# Networking Outputs
# ==============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

# ==============================================================================
# Application Outputs - NEW!
# ==============================================================================

output "application_url" {
  description = "URL to access the application"
  value       = "http://${module.application.alb_dns_name}"
}

# EXPLANATION:
# - This is the URL you'll copy/paste into browser
# - Formatted as clickable HTTP URL
# - Example: http://webapp-dev-alb-123456.us-east-1.elb.amazonaws.com

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.application.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.application.ecs_cluster_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for application logs"
  value       = module.application.cloudwatch_log_group_name
}

# EXPLANATION:
# - These outputs make it easy to find your resources
# - After terraform apply, you'll see all these values
# - Copy the application_url and open in browser!