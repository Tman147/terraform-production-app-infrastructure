# ==============================================================================
# Auto-Scaling Module - Outputs
# ==============================================================================

output "autoscaling_target_id" {
  description = "Resource ID of the auto-scaling target"
  value       = aws_appautoscaling_target.ecs.resource_id
}

output "cpu_scaling_policy_arn" {
  description = "ARN of the CPU-based scaling policy"
  value       = aws_appautoscaling_policy.ecs_cpu.arn
}

output "cpu_scaling_policy_name" {
  description = "Name of the CPU-based scaling policy"
  value       = aws_appautoscaling_policy.ecs_cpu.name
}

output "memory_scaling_policy_arn" {
  description = "ARN of the memory-based scaling policy"
  value       = aws_appautoscaling_policy.ecs_memory.arn
}

output "memory_scaling_policy_name" {
  description = "Name of the memory-based scaling policy"
  value       = aws_appautoscaling_policy.ecs_memory.name
}

output "min_capacity" {
  description = "Minimum task capacity"
  value       = var.min_capacity
}

output "max_capacity" {
  description = "Maximum task capacity"
  value       = var.max_capacity
}