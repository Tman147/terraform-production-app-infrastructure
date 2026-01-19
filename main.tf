# ==============================================================================
# Terraform Configuration
# ==============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# - Specifies which version of Terraform and AWS provider to use
# - "~> 5.0" means "5.x" (any 5.x version, but not 6.0)

# ==============================================================================
# AWS Provider Configuration
# ==============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# - Configures AWS provider
# - default_tags → Automatically tags ALL resources we create


# ==============================================================================
# Networking Module
# ==============================================================================

module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
}

# - module "networking" → Calls our networking module
# - We pass in values for the module's variables

# ==============================================================================
# Application Module
# ==============================================================================

module "application" {
  source = "./modules/application"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
  
  # Application configuration
  container_image     = "nginx:latest"
  container_port      = 80
  desired_count       = 2
  cpu                 = 256
  memory              = 512
  allowed_cidr_blocks = ["0.0.0.0/0"]  # Allow access from anywhere
}

# - module "application" → Calls our application module
# - We pass networking outputs as inputs:
#   - vpc_id → Where to create security groups
#   - public_subnet_ids → Where to put ALB
#   - private_subnet_ids → Where to put ECS tasks
# - Application config:
#   - nginx:latest → Simple web server for demo
#   - cpu/memory → Minimal for cost control
#   - desired_count = 2 → High availability

# ==============================================================================
# Monitoring Module
# ==============================================================================

module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email

  cluster_name             = module.application.ecs_cluster_name
  service_name             = module.application.ecs_service_name
  alb_arn_suffix           = module.application.alb_arn_suffix
  target_group_arn_suffix  = module.application.target_group_arn_suffix
}

