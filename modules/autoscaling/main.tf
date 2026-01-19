# ==============================================================================
# Auto-Scaling Module - ECS Service Auto-Scaling
# ==============================================================================

# ------------------------------------------------------------------------------
# Auto-Scaling Target
# ------------------------------------------------------------------------------

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-scaling-target"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Defines the resource to scale (ECS service)
# - Sets min/max boundaries for task count
# - resource_id format: service/{cluster-name}/{service-name}
# - scalable_dimension: What to scale (desired task count)

# ------------------------------------------------------------------------------
# Auto-Scaling Policy - Target Tracking (CPU)
# ------------------------------------------------------------------------------

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${var.project_name}-${var.environment}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.target_cpu_utilization
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

# EXPLANATION:
# - Target Tracking = AWS automatically calculates when to scale
# - Metric: ECSServiceAverageCPUUtilization (across all tasks)
# - Target: 70% CPU utilization
# - Scale out (add tasks): Fast (60 sec cooldown)
# - Scale in (remove tasks): Slow (300 sec cooldown) - more conservative

# HOW IT WORKS:
# Current CPU 80%, Target 70%:
# ├─ Above target → Scale out (add tasks)
# ├─ Wait 60 seconds before checking again
# └─ More tasks → CPU drops toward 70%

# Current CPU 50%, Target 70%:
# ├─ Below target → Scale in (remove tasks)
# ├─ Wait 300 seconds before removing more
# └─ Fewer tasks → CPU rises toward 70%

# ------------------------------------------------------------------------------
# Optional: Memory-Based Scaling Policy
# ------------------------------------------------------------------------------

resource "aws_appautoscaling_policy" "ecs_memory" {
  name               = "${var.project_name}-${var.environment}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 70
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

# EXPLANATION:
# - Also track memory utilization
# - If EITHER CPU or memory hits threshold → scale
# - Protects against both CPU-bound and memory-bound bottlenecks
# - Conservative: scales based on whichever metric needs it

# WHY BOTH METRICS:
# - Some apps are CPU-intensive (computation)
# - Some apps are memory-intensive (caching, data processing)
# - Covering both ensures you scale when needed