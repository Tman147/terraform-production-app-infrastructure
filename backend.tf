# ==============================================================================
# Terraform Backend Configuration - Remote State in S3
# ==============================================================================

terraform {
  backend "s3" {
    bucket         = "webapp-terraform-state-930056746901"  # ← CHANGE THIS to your bucket name
    key            = "webapp/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# EXPLANATION:
# - bucket: Where state file is stored (created in bootstrap)
# - key: Path within bucket (webapp/terraform.tfstate)
# - region: AWS region for S3 bucket
# - encrypt: Use server-side encryption
# - dynamodb_table: For state locking
