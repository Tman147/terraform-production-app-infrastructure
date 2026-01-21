# ==============================================================================
# Application Module Variables
# ==============================================================================

variable "project_name" {
  description = "Production build app"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where application will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "container_image" {
  description = "Docker image to deploy"
  type        = string
  default     = "nginx:latest"  
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "desired_count" {
  description = "Number of container instances to run"
  type        = number
  default     = 2  # Run 2 containers for high availability
}

variable "cpu" {
  description = "CPU units for the task (256 = 0.25 vCPU)"
  type        = number
  default     = 256  
}

variable "memory" {
  description = "Memory for the task in MB"
  type        = number
  default     = 512  
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Allow from anywhere, but restrict in production
}

# ==============================================================================
# Database Connection Variables (Phase 3)
# ==============================================================================

variable "db_address" {
  description = "Database hostname"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = ""
}

variable "db_secret_arn" {
  description = "ARN of the database credentials secret"
  type        = string
  default     = ""
}

variable "environment_variables" {
  description = "Additional environment variables for containers"
  type        = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "aws_region" {
  description = "AWS region for CloudWatch logs"
  type        = string
  default     = "us-east-1"
}