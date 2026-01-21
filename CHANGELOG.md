# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-01-21

### Added - Phase 3: Secrets Management & Database

#### AWS Secrets Manager Integration
- Secrets module for secure credential storage
- Random password generation with 32-character complexity requirements
- KMS encryption for secrets at rest
- JSON secret structure containing database connection details (username, password, engine, port, dbname)
- Secret rotation configuration prepared (requires Lambda function for full implementation)
- Secret naming with prefix for uniqueness: `webapp-dev-db-credentials-*`

#### RDS PostgreSQL Database
- PostgreSQL 15 deployment (flexible version to support AWS Academy)
- db.t3.micro instance class (free tier eligible)
- 20GB gp3 encrypted storage with auto-scaling enabled (max 100GB)
- Single-AZ deployment (AWS Academy free tier constraint)
- Automated backups with 1-day retention period (free tier compliant)
- Backup window: 3-4 AM UTC
- Maintenance window: Monday 4-5 AM UTC
- CloudWatch logs export enabled for PostgreSQL and upgrade events
- DB subnet group spanning both private subnets (10.0.11.0/24, 10.0.12.0/24)
- Security group allowing PostgreSQL (port 5432) from private subnet CIDRs only
- CIDR-based security rules instead of security group references (to avoid circular dependency)
- Deletion protection disabled for dev environment (configurable for production)
- Skip final snapshot enabled for dev (configurable for production)
- Point-in-time recovery via automated backups

#### ECS Database Integration
- Updated task definition with database connection environment variables:
  - `DB_HOST`: RDS endpoint hostname
  - `DB_PORT`: PostgreSQL port (5432)
  - `DB_NAME`: Database name (appdb)
- Secrets injection from AWS Secrets Manager at container runtime:
  - `DB_USERNAME`: Master database username (dbadmin)
  - `DB_PASSWORD`: Randomly generated 32-character password
- Conditional logic in task definition to only inject DB variables when database exists
- IAM permissions added for ECS task execution role to read Secrets Manager
- Updated application module variables to accept database connection parameters
- Task definition now references secrets using ARN with JSON key path format

### Changed
- Application module variables: Added `db_address`, `db_port`, `db_name`, `db_secret_arn`, `aws_region`, `environment_variables`
- Application task definition: Enhanced `container_definitions` with database environment variables and secrets
- Networking module outputs: Added `private_subnet_cidrs` for database security group CIDR-based rules
- Application module outputs: Fixed `ecs_security_group_id` to correctly reference `aws_security_group.ecs_tasks.id`
- Database module configuration: Adjusted for AWS Academy free tier compatibility
- Root `main.tf`: Reordered modules to place secrets before database (dependency order)

### Fixed

#### Circular Dependency Resolution
- **Problem**: Database module needed `ecs_security_group_id` from application, but application needed database outputs
- **Solution**: Replaced security group reference with CIDR-based rules using private subnet CIDR blocks
- **Implementation**: Database security group now allows traffic from `10.0.11.0/24` and `10.0.12.0/24`
- **Trade-off**: Allows any resource in private subnets to access database (acceptable in controlled environment)
- **Alternative considered**: Separate security module to create all SGs first (deemed unnecessarily complex)

#### AWS Academy Free Tier Compatibility
- **Issue 1**: PostgreSQL 15.4 not available in AWS Academy
  - **Error**: `InvalidParameterCombination: Cannot find version 15.4 for postgres`
  - **Solution**: Changed to flexible version "15" to let AWS select latest available
- **Issue 2**: 7-day backup retention exceeded free tier limit
  - **Error**: `FreeTierRestrictionError: backup retention period exceeds maximum`
  - **Solution**: Reduced backup retention from 7 days to 1 day
- **Issue 3**: Multi-AZ deployment not allowed in free tier
  - **Solution**: Disabled Multi-AZ (set to false)
- **Production note**: These would be re-enabled in real AWS account (Multi-AZ: true, retention: 7)

#### Missing Module Output
- **Problem**: Terraform validation failed with "private_subnet_cidrs attribute not expected"
- **Cause**: Database module referenced `module.networking.private_subnet_cidrs` but output didn't exist
- **Solution**: Added `private_subnet_cidrs` output to networking module using `aws_subnet.private[*].cidr_block`
- **Lesson**: Always verify module outputs exist before referencing in other modules

#### IAM Secrets Manager Permissions
- **Problem**: ECS tasks failed to start with `AccessDeniedException: secretsmanager:GetSecretValue`
- **Symptom**: Tasks stopped immediately after creation with error message in stopped reason
- **Root cause**: `ecsTaskExecutionRole` lacked permission to read Secrets Manager secrets
- **Solution**: Added inline IAM policy granting `secretsmanager:GetSecretValue` on `webapp-dev-db-credentials-*`
- **Permission scope**: Limited to secrets with specific prefix for least-privilege access
- **Why it happened**: Added secrets to task definition but forgot execution role permission
- **Lesson**: Secrets injection requires both task definition reference AND IAM permission

#### ECS Task Definition Deployment
- **Observation**: New task definition created (revision 7+) but service still running old tasks (revision 6)
- **Cause**: ECS service doesn't automatically deploy new task definitions in all cases
- **Solution**: Force new deployment via ECS console "Update service" → "Force new deployment"
- **Alternative**: AWS CLI command `aws ecs update-service --force-new-deployment`
- **Future improvement**: Consider adding deployment configuration to automate updates

#### Application Module Output Reference
- **Problem**: Output referenced `aws_security_group.ecs.id` but resource named `ecs_tasks`
- **Solution**: Corrected output to reference `aws_security_group.ecs_tasks.id`
- **Impact**: Fixed reference error that would have caused issues if output was used

### Infrastructure

#### Cost Impact (if running 24/7)
- RDS db.t3.micro (single-AZ): ~$12-15/month
- Secrets Manager: $0.40/month per secret
- Additional CloudWatch logs: ~$1/month
- **Phase 3 total**: ~$13-16/month
- **Combined infrastructure cost**: ~$66-115/month (depending on auto-scaling)
- **Production with Multi-AZ**: ~$90-140/month

#### Deployment Time
- Secrets Manager resources: ~30 seconds
- Database subnet group: ~10 seconds
- RDS security group: ~10 seconds
- RDS instance creation: **10-15 minutes** (single-AZ)
- ECS task definition update: ~30 seconds
- ECS service rolling update: ~2-3 minutes
- **Total Phase 3 deployment time**: ~15-20 minutes

### Technical Decisions

#### Security Architecture
- **CIDR-based security rules**: Chose simplicity over security group references
  - Rationale: Private subnets are isolated and fully controlled
  - Trade-off: Less granular than SG-to-SG rules, but adequate for use case
  - Alternative: Separate security module (more complex, unnecessary for project scope)
  
#### Secrets Management
- **Secrets Manager over Parameter Store**: 
  - Better rotation capabilities (prepared for Lambda integration)
  - Enhanced audit trail and monitoring
  - Automatic encryption with KMS
  - JSON structure for multiple related values
  
#### Storage Configuration
- **gp3 over gp2**: Better price/performance ratio
- **Storage auto-scaling**: Prevents out-of-space scenarios without manual intervention
- **Encryption at rest**: AWS managed KMS key (could upgrade to customer-managed key)

#### Backup Strategy
- **1-day retention**: Free tier maximum (would use 7 days in production)
- **Backup window**: 3-4 AM UTC (low-traffic period assumption)
- **Point-in-time recovery**: Enabled via automated backups
- **Final snapshot**: Skipped for dev to allow rapid destroy/rebuild cycle

#### Deployment Model
- **Single-AZ**: Cost optimization for dev/learning environment
- **Production consideration**: Would enable Multi-AZ for high availability
- **RTO/RPO trade-off**: Acceptable for non-critical development workload

### Known Limitations

#### AWS Academy Constraints
- Multi-AZ deployment disabled (free tier restriction)
- Backup retention limited to 1 day (free tier maximum)
- PostgreSQL version flexibility required (specific minor versions not available)
- These limitations documented for future migration to production AWS account

#### Incomplete Features
- Secret rotation Lambda not implemented (infrastructure prepared, requires Phase 4)
- Single NAT Gateway (would add second for true HA in production Multi-AZ)
- Performance Insights disabled (cost optimization, would enable for production monitoring)

#### Security Considerations
- CIDR-based rules allow any private subnet resource to access database
  - Mitigated by: Private subnets have no internet gateway, fully controlled environment
  - Future enhancement: Implement separate security module for tighter SG-to-SG rules
  
### Documentation Updates
- Enhanced README with Phase 3 architecture, troubleshooting, and database configuration
- Updated notes.md with detailed challenge resolutions and lessons learned
- Added IAM permission requirements to deployment prerequisites
- Documented RDS creation timing expectations (10-15 minutes)

---

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

---

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

---

## [0.1.0] - 2025-01-18

### Added
- Project initialization
- Basic Terraform structure
- Repository setup with version control

---

## Upcoming - [4.0.0] Phase 4: Enhanced Security & Features (Planned)

### Planned Features

#### HTTPS & Custom Domain
- ACM certificate for SSL/TLS
- Route53 hosted zone and DNS records
- HTTP to HTTPS redirect
- ALB listener rules for HTTPS (port 443)

#### Advanced Security
- WAF (Web Application Firewall) with managed rule sets
- Container image vulnerability scanning (ECR image scanning)
- Lambda function for automatic secret rotation (30-day cycle)
- Security Hub integration for compliance monitoring

#### Enhanced Observability
- AWS X-Ray distributed tracing
- Custom CloudWatch dashboards
- Log aggregation and analysis
- Application performance monitoring

#### Disaster Recovery
- Cross-region RDS read replica
- Automated backup testing procedures
- Documented RTO/RPO targets
- Multi-region failover capability

---

## Version History Summary

- **v3.0.0** (Current): Complete database layer with secrets management
- **v2.0.0**: Production-grade with auto-scaling, monitoring, and CI/CD
- **v1.0.0**: Core infrastructure with multi-AZ HA
- **v0.1.0**: Initial project structure

---

## Notes

### Semantic Versioning Guidelines
- **Major (X.0.0)**: Breaking changes or significant new features (new phases)
- **Minor (0.X.0)**: New features, backward compatible
- **Patch (0.0.X)**: Bug fixes, minor improvements

### Cost Optimization Strategy
Current practice: Infrastructure destroyed when not in active use. Rebuild time via GitHub Actions: ~15-20 minutes.

**Monthly cost if running 24/7**: 
- Development (Single-AZ): ~$66-115/month
- Production (Multi-AZ): ~$90-140/month

### AWS Academy Considerations
This project is developed within AWS Academy constraints:
- Free tier limitations accommodated (Single-AZ, 1-day backups)
- Production-ready patterns documented separately
- Easy migration path to full AWS account for production deployment

### Lessons Learned

#### Phase 3 Key Takeaways
1. **Module Dependencies**: Always check for circular dependencies before adding cross-module references
2. **IAM Permissions**: When adding new AWS services to ECS, update execution role permissions
3. **Free Tier Constraints**: Test configurations against account limits early in development
4. **Security Trade-offs**: CIDR-based rules vs SG references - choose appropriate level for use case
5. **RDS Timing**: Plan for 10-15 minute deployment windows when creating databases
6. **Secrets Management**: Proper implementation requires both task definition AND IAM permissions