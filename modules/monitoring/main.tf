# ==============================================================================
# Monitoring Module - CloudWatch Alarms and SNS
# ==============================================================================

# ------------------------------------------------------------------------------
# SNS Topic for Alerts
# ------------------------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name         = "${var.project_name}-${var.environment}-alerts"
  display_name = "${var.project_name} ${var.environment} Alerts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-alerts"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# SNS Topic Subscription - Email
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EXPLANATION:
# - SNS Topic = Notification channel
# - Email subscription = Where alerts go
# - You'll receive confirmation email after terraform apply
# - Must click "Confirm subscription" to start receiving alerts

# ------------------------------------------------------------------------------
# ECS Alarms
# ------------------------------------------------------------------------------

# Alarm: Unhealthy Tasks
resource "aws_cloudwatch_metric_alarm" "unhealthy_tasks" {
  alarm_name          = "${var.project_name}-${var.environment}-unhealthy-tasks"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when tasks are unhealthy in target group"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-unhealthy-tasks"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Monitors ALB target group health
# - Triggers when UnHealthyHostCount > 0
# - evaluation_periods = 2 means: Must be unhealthy for 2 minutes straight
# - ok_actions sends email when alarm clears (returns to healthy)

# Alarm: High CPU Usage
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when ECS service CPU utilization > 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = var.service_name
    ClusterName = var.cluster_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-high-cpu"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Monitors ECS service CPU usage
# - Triggers when average CPU > 80% for 10 minutes (2 × 5 min periods)
# - Could indicate need to scale up or optimize application

# Alarm: High Memory Usage
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when ECS service memory utilization > 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = var.service_name
    ClusterName = var.cluster_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-high-memory"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Monitors ECS service memory usage
# - Triggers when average memory > 80% for 10 minutes
# - Could indicate memory leak or need for more memory

# ------------------------------------------------------------------------------
# ALB Alarms
# ------------------------------------------------------------------------------

# Alarm: High 5xx Error Rate
resource "aws_cloudwatch_metric_alarm" "high_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-high-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when target returns > 10 5xx errors in 2 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-high-5xx"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Monitors 5xx errors from your application
# - Triggers when more than 10 errors in 2 minutes
# - Indicates application problems (crashes, timeouts, etc.)

# Alarm: Slow Response Time
resource "aws_cloudwatch_metric_alarm" "slow_response" {
  alarm_name          = "${var.project_name}-${var.environment}-slow-response"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when average response time > 1 second"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-slow-response"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Monitors ALB target response time
# - Triggers when average response > 1 second for 10 minutes
# - Indicates performance degradation
# - For nginx static pages, should be <100ms; 1 second is very slow