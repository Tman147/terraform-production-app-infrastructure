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
# Application Module - with Database Connection
# ==============================================================================

module "application" {
  source = "./modules/application"

  project_name = var.project_name
  environment  = var.environment

  # Networking
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids

  # Application configuration
  container_image     = "nginx:latest"
  container_port      = 80
  desired_count       = 2
  cpu                 = 256
  memory              = 512
  allowed_cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere

  # Database connection info (Phase 3 - NEW)
  db_address    = module.database.db_address
  db_port       = module.database.db_port
  db_name       = module.database.db_name
  db_secret_arn = module.secrets.secret_arn
  aws_region    = var.aws_region

  # Ensure database exists before deploying application
  depends_on = [module.database]
}

# - module "application" → Calls our application module (ECS Fargate + ALB)
# 
# Networking inputs (from networking module):
#   - vpc_id → Where to create security groups and network resources
#   - public_subnet_ids → Where to deploy the Application Load Balancer
#   - private_subnet_ids → Where to deploy ECS tasks (isolated from internet)
# 
# Application configuration:
#   - container_image: nginx:latest → Simple web server for demo/testing
#   - container_port: 80 → Port the container listens on
#   - desired_count: 2 → Run 2 containers for high availability
#   - cpu: 256 (0.25 vCPU) → Minimal compute for cost control
#   - memory: 512 MB → Minimal memory for cost control
#   - allowed_cidr_blocks: 0.0.0.0/0 → Allow ALB access from anywhere
# 
# Database connection (Phase 3 - NEW):
#   - db_address → RDS endpoint hostname injected as DB_HOST environment variable
#   - db_port → Database port (5432) injected as DB_PORT environment variable
#   - db_name → Database name (appdb) injected as DB_NAME environment variable
#   - db_secret_arn → ARN of Secrets Manager secret containing DB username/password
#                     Credentials are securely injected into containers at runtime
#   - aws_region → Required for CloudWatch logs configuration
# 
# Dependencies:
#   - depends_on = [module.database] → Ensures database is created before application
#                                       Prevents ECS tasks from starting before DB exists
# 
# How database credentials work:
#   1. Secrets Manager stores username/password (encrypted)
#   2. ECS task definition references secret ARN
#   3. At container startup, AWS injects credentials as environment variables:
#      - DB_USERNAME (from secret)
#      - DB_PASSWORD (from secret)
#   4. Application code can read these env vars to connect to database
#   5. Credentials never appear in Terraform state or container logs


# ==============================================================================
# Database Module
# ==============================================================================

module "database" {
  source = "./modules/database"

  project_name = var.project_name
  environment  = var.environment

  # Networking (from networking module)
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  # Security (from application module)
  private_subnet_cidrs = module.networking.private_subnet_cidrs  # Dynamic reference  # your private subnet CIDRs

  # Database credentials (from secrets module)
  db_name     = module.secrets.db_name
  db_username = module.secrets.db_username
  db_password = module.secrets.db_password

  # Database configuration
  postgres_version      = "15"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 100

  # High availability
  multi_az = true

  # Backups
  backup_retention_days = 1

  # Cost optimization for dev environment
  enable_performance_insights = false
  deletion_protection         = false
  skip_final_snapshot         = true
}

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

# ==============================================================================
# Auto-Scaling Module
# ==============================================================================

module "autoscaling" {
  source = "./modules/autoscaling"

  project_name = var.project_name
  environment  = var.environment

  cluster_name = module.application.ecs_cluster_name
  service_name = module.application.ecs_service_name

  min_capacity            = 2
  max_capacity            = 10
  target_cpu_utilization  = 70
  scale_in_cooldown       = 300  # 5 minutes
  scale_out_cooldown      = 60   # 1 minute
}

# ==============================================================================
# Secrets Module
# ==============================================================================

module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  environment  = var.environment
  db_username  = "dbadmin"
  db_name      = "appdb"
}
