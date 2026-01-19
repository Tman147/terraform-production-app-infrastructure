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