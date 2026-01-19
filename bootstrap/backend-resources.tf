# ==============================================================================
# Terraform Backend Resources - Bootstrap
# ==============================================================================
# Run this ONCE to create S3 bucket and DynamoDB table for remote state
# Then configure backend in main project
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

provider "aws" {
  region = "us-east-1"
}

# ------------------------------------------------------------------------------
# S3 Bucket for Terraform State
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = "webapp-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State Bucket"
    Purpose     = "Store Terraform state files"
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Bucket name must be globally unique across ALL AWS
# - Including account ID ensures uniqueness
# - Example: webapp-terraform-state-930056746901

# Block public access (security best practice)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# EXPLANATION:
# - Prevents bucket from being publicly accessible
# - State files contain sensitive resource IDs
# - Should NEVER be public

# Enable versioning (can recover old state)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# EXPLANATION:
# - Keeps history of all state file changes
# - Can rollback if state gets corrupted
# - Disaster recovery capability

# Enable encryption (security best practice)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# EXPLANATION:
# - Encrypts state files at rest
# - State files may contain sensitive data
# - No additional cost for S3 SSE

# ------------------------------------------------------------------------------
# DynamoDB Table for State Locking
# ------------------------------------------------------------------------------

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Purpose     = "Lock state during Terraform operations"
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Prevents multiple people running terraform apply simultaneously
# - PAY_PER_REQUEST = only pay for actual usage (cheap)
# - Hash key "LockID" is required by Terraform

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "backend_config" {
  description = "Backend configuration to add to main project"
  value = <<-EOT
    Add this to your main project's backend configuration:
    
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.bucket}"
        key            = "terraform.tfstate"
        region         = "us-east-1"
        encrypt        = true
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
      }
    }
  EOT
}