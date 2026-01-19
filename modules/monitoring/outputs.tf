# ==============================================================================
# Monitoring Module - Outputs
# ==============================================================================

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "alarm_names" {
  description = "List of CloudWatch alarm names"
  value = [
    aws_cloudwatch_metric_alarm.unhealthy_tasks.alarm_name,
    aws_cloudwatch_metric_alarm.high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.high_memory.alarm_name,
    aws_cloudwatch_metric_alarm.high_5xx_errors.alarm_name,
    aws_cloudwatch_metric_alarm.slow_response.alarm_name,
  ]
}