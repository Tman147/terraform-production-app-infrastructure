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
# Application Outputs
# ==============================================================================

output "application_url" {
  description = "URL to access the application"
  value       = "http://${module.application.alb_dns_name}"
}

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

# - These outputs make it easy to find your resources
# - After terraform apply, you'll see all these values
# - Copy the application_url to the browser

# ==============================================================================
# Monitoring Outputs
# ==============================================================================

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_alarms" {
  description = "List of CloudWatch alarm names"
  value       = module.monitoring.alarm_names
}