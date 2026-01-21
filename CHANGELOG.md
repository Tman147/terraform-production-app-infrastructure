# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-01-19

### Added - Phase 2: Scaling & Observability

#### Auto-Scaling
- ECS auto-scaling module with target tracking policies
- CPU utilization target tracking (70% threshold)
- Memory utilization target tracking (80% threshold)
- Configurable min/max task counts (1-10 tasks)
- Scale-out and scale-in policies with appropriate cooldown periods

#### Monitoring & Alerting
- Comprehensive CloudWatch monitoring module
- Five critical CloudWatch alarms:
  - High CPU utilization (> 80% for 2 minutes)
  - High memory utilization (> 80% for 2 minutes)
  - High 5xx error rate (> 10 errors in 5 minutes)
  - Slow response time (> 1 second average for 5 minutes)
  - Unhealthy host count (< 1 healthy host for 1 minute)
- SNS topic for email notifications
- Email subscription for alarm notifications

#### Remote State Management
- S3 backend configuration for remote state storage
- State bucket: `webapp-terraform-state-930056746901`
- S3 bucket versioning enabled for state history
- Server-side encryption (SSE-S3) on state bucket
- DynamoDB table `webapp-terraform-locks` for state locking
- Lifecycle policy for managing old state versions
- Migration from local state to remote state

#### CI/CD Pipeline
- GitHub Actions workflow for automated Terraform deployments
- Automatic infrastructure deployment on push to `main` branch
- Workflow steps: checkout, AWS configuration, init, validate, plan, apply
- AWS credentials stored as GitHub repository secrets
- Terraform version pinned to 1.9.8 for consistency

#### Documentation
- Expanded README.md with Phase 2 features
- Added monitoring and alerting documentation
- Documented auto-scaling behavior
- Added CI/CD deployment instructions
- Enhanced cost estimation with new resources
- Created development notes (notes.md) with design decisions

### Changed
- Consolidated IAM policies into single comprehensive custom policy
- Combined ECS, ECR, CloudWatch, S3, DynamoDB, EC2, and ELB permissions
- Replaced multiple AWS managed policy attachments with single custom policy
- Updated project structure documentation to reflect new modules
- Enhanced outputs to include monitoring and auto-scaling information

### Fixed
- IAM policy management in restricted AWS Academy lab environment
- State locking conflicts through DynamoDB integration
- Improved security group references using SG IDs instead of CIDR blocks

### Infrastructure
- **Cost Impact**: Added ~$1-2/month for CloudWatch alarms and S3/DynamoDB state management
- **Scaling**: Infrastructure now auto-scales from 1 to 10 tasks based on demand
- **Reliability**: Multi-AZ with automated health checks and alarming
- **Automation**: Zero-touch deployments via GitHub Actions

## [1.0.0] - 2025-01-16

### Added
- Initial infrastructure deployment
- Networking module (VPC, subnets, NAT gateway)
- Application module (ECS, ALB, security groups)
- CloudWatch logging integration
- Multi-AZ high availability setup

### Fixed
- IAM role creation issue - switched to data source for existing roles

### Changed
- Reduced ECS task CPU/memory for cost optimization (0.25 vCPU, 512MB)

### Technical Decisions
- Chose NAT Gateway over NAT instance for reliability (~$32/month vs ~$5/month)
- Selected Fargate over EC2 launch type for simplified management
- Implemented security group layering (ALB → ECS only)

## [0.1.0] - 2025-01-18

### Added
- Project initialization
- Basic Terraform structure
- Repository setup with version control

---

## Upcoming - [3.0.0] Phase 3: Secrets & Database (Planned)

### Planned Features
- AWS Secrets Manager integration
  - Secure credential storage with KMS encryption
  - Automatic secret rotation (30-day cycle)
  - ECS task role access permissions
  
- RDS PostgreSQL deployment
  - Multi-AZ database for high availability
  - Automated backups (7-day retention)
  - Point-in-time recovery capability
  - Security group configuration (ECS → RDS only)
  - Subnet group across private subnets
  
- Application integration
  - ECS task definition updates with secret references
  - Database connection environment variables
  - Secure credential injection at runtime

### Estimated Timeline
- Development: 3-4 hours
- Testing: 1-2 hours
- Documentation: 1 hour

---

## Version History Summary

- **v2.0.0** (Current): Production-grade with auto-scaling, monitoring, and CI/CD
- **v1.0.0**: Core infrastructure with multi-AZ HA
- **v0.1.0**: Initial project structure

## Notes

### Semantic Versioning Guidelines
- **Major (X.0.0)**: Breaking changes or significant new features (new phases)
- **Minor (0.X.0)**: New features, backward compatible
- **Patch (0.0.X)**: Bug fixes, minor improvements

### Cost Optimization Strategy
Current practice: Infrastructure destroyed when not in active use. Rebuild time via GitHub Actions: ~10 minutes.

**Monthly cost if running 24/7**: ~$54-99 depending on auto-scaling activity