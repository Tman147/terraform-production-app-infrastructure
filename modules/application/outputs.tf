# ==============================================================================
# Application Module Outputs
# ==============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

# EXPLANATION:
# - This is the URL you'll use to access your application
# - Example: webapp-dev-alb-1234567890.us-east-1.elb.amazonaws.com
# - You can visit this in a browser to see nginx running

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

# EXPLANATION:
# - ARN = Amazon Resource Name (unique identifier)
# - Useful for CloudWatch dashboards, alerts, etc.

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

# EXPLANATION:
# - Used if you want to create Route53 DNS records
# - Not needed for basic setup, but good practice to expose

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

# EXPLANATION:
# - Cluster identifier
# - Useful if you want to deploy additional services to same cluster

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

# EXPLANATION:
# - Human-readable cluster name
# - Useful for scripts, monitoring dashboards

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

# EXPLANATION:
# - Service name
# - Useful for AWS CLI commands, monitoring

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

# EXPLANATION:
# - Where container logs are stored
# - You'll use this to view application logs

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.app.arn
}

# EXPLANATION:
# - Identifies the task definition
# - Includes version number (updates on each change)

output "security_group_alb_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

# EXPLANATION:
# - Security group ID for the ALB
# - Useful if you need to add additional ingress rules later

output "security_group_ecs_tasks_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

# EXPLANATION:
# - Security group ID for ECS tasks
# - Useful if you need to allow access to other resources (like RDS)

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}

# EXPLANATION:
# - Target group identifier
# - Useful for monitoring target health