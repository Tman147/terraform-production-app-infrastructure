# Development Notes

## 2026-01-16 - Initial Setup

Started with networking module. Key decision: using NAT gateway instead of NAT instance for better reliability, even though it costs more (~$32/month vs ~$5/month).

## 2026-01-18 - IAM Issues

Hit IAM permissions error - lab account doesn't allow `iam:CreateRole`. Fixed by using data source to reference existing `ecsTaskExecutionRole`. Good reminder that enterprise environments often have restricted permissions.

## 2026-01-18 - ECS Configuration

Chose Fargate over EC2 launch type:
- Pros: No instance management, pay per task
- Cons: Slightly more expensive, less control
- For this project: Fargate makes sense (simplicity > cost)

Set task size to 0.25 vCPU / 512MB - smallest option. Good for demo/learning. Production would need load testing to determine right size.

## 2026-01-18 - Security Groups

Important lesson: Security groups are stateful - return traffic allowed automatically. Only need to define inbound rules for request traffic.

ALB → ECS rule uses security group reference (not CIDR) - better than hardcoding IPs since it dynamically allows from ALB even if ALB IPs change.

## 2026-01-19 - Phase 2: Monitoring & Observability

Created CloudWatch alerts for monitoring - High CPU, High Memory, High 5xx error, slow response times, and unhealthy host. 

Created S3 bucket and uploaded terraform.tfstate. Now utilizing cloud to manage state locking in DynamoDB.

Added comprehensive CloudWatch monitoring:
- **Metrics**: CPU utilization, memory utilization, ALB response times, 5xx errors, healthy host count
- **Alarms**: Set thresholds for each metric with SNS email notifications
- **Auto-scaling**: Target tracking based on CPU (70%) and memory (80%) utilization
- **Scaling policies**: Scale out when under load, scale in during low traffic

Key learnings:
- CloudWatch Alarms require SNS topic subscription confirmation via email
- Auto-scaling policies use target tracking - AWS automatically adjusts desired count
- Monitoring is critical for SRE work - can't manage what you don't measure

## 2026-01-19 - Remote State & Collaboration

Migrated from local state to remote state backend:
- **S3 bucket**: `webapp-terraform-state-930056746901` with versioning enabled
- **DynamoDB table**: `webapp-terraform-locks` for state locking
- **Benefits**: Team collaboration, state history, prevents concurrent modifications

Bucket configuration:
- Versioning enabled for state file recovery
- Server-side encryption (SSE-S3)
- Lifecycle policy to manage old versions

## 2026-01-19 - CI/CD with GitHub Actions

Implemented GitHub Actions workflow for automated deployments:
- **Trigger**: Push to `main` branch
- **Steps**: Checkout → Configure AWS → Terraform init/validate/plan/apply
- **Secrets**: AWS credentials stored in GitHub repository secrets
- **Benefits**: Consistent deployments, audit trail, no local terraform apply needed

Workflow runs automatically on push. Can also trigger with empty commit:
```bash
git commit --allow-empty -m "Rebuild infrastructure"
git push
```

## 2026-01-19 - IAM Consolidation

Consolidated multiple IAM policy attachments into single comprehensive policy:
- Combined ECS, ECR, CloudWatch, S3, DynamoDB, EC2, ELB permissions
- Attached via `aws_iam_role_policy_attachment` with custom policy ARN
- Cleaner than multiple AWS managed policies
- Lesson: AWS Academy lab accounts have specific restrictions - work within guardrails

## 2026-01-19 - Cost Optimization Strategy

Current approach: Destroy infrastructure when not actively working
- **Rebuild time**: ~10 minutes with GitHub Actions automation
- **Cost savings**: ~$30-40/month avoided when destroyed
- **Trade-off**: Acceptable for learning project vs. keeping 24/7

Command to rebuild: Push to GitHub or run `terraform apply` locally

## 2026-01-21 - Phase 3: Secrets Manager & RDS Database

Successfully deployed database layer to the infrastructure.

### Secrets Manager
- Created secrets module for secure credential management
- Random password generation (32 characters with complexity requirements)
- KMS encryption for secrets at rest
- Secrets stored in JSON format with all database connection details
- Secret rotation configuration prepared (requires Lambda function for full implementation)

### RDS PostgreSQL
- PostgreSQL 15 (latest minor version - AWS Academy didn't support 15.4 specifically)
- db.t3.micro instance (free tier eligible)
- 20GB gp3 encrypted storage with auto-scaling enabled (max 100GB)
- Single-AZ deployment (AWS Academy free tier constraint)
- 1-day automated backup retention (free tier maximum, originally wanted 7 days)
- Deployed in private subnets (10.0.11.0/24, 10.0.12.0/24)
- Security group allows PostgreSQL (5432) from private subnet CIDRs only
- CloudWatch logs export enabled for PostgreSQL and upgrade events
- Backup window: 3-4 AM UTC
- Maintenance window: Monday 4-5 AM UTC
- **Creation time**: 10-15 minutes for single-AZ RDS instance

### ECS Integration
- Updated task definition with database connection environment variables:
  - `DB_HOST`: RDS endpoint hostname
  - `DB_PORT`: PostgreSQL port (5432)
  - `DB_NAME`: Database name (appdb)
- DB credentials securely injected from Secrets Manager at container runtime:
  - `DB_USERNAME`: Master database username (dbadmin)
  - `DB_PASSWORD`: Randomly generated 32-character password
- No credentials stored in code, container images, or Terraform state
- Task definition uses conditional logic to only inject DB variables when database exists

### Challenges Resolved

**Circular Dependency:**
- **Problem**: Database module needed ECS security group ID, but application module needed database outputs
- **Root cause**: Both modules depended on each other, creating impossible dependency graph
- **Solution**: Used CIDR-based security rules instead of security group references
- **Trade-off**: Allows any resource in private subnets to access database (not just ECS)
- **Security justification**: Private subnets have no internet gateway, are fully controlled by us
- **Lesson learned**: Module boundaries are hard - always check for circular dependencies before adding new modules
- **Alternative considered**: Separate security module to create all SGs first (more complex, unnecessary for this project)

**AWS Academy Free Tier Restrictions:**
- PostgreSQL 15.4 not available → Used flexible version "15" (AWS selects latest available)
- 7-day backup retention not allowed → Reduced to 1 day (free tier maximum)
- Multi-AZ deployment not allowed → Disabled for cost compliance
- Error message format: "FreeTierRestrictionError" - clear indication of constraint

**Missing Networking Module Output:**
- **Problem**: GitHub Actions validation failed with "private_subnet_cidrs" attribute not found
- **Cause**: Database module referenced `module.networking.private_subnet_cidrs` but output didn't exist
- **Solution**: Added output to `modules/networking/outputs.tf` using `aws_subnet.private[*].cidr_block`
- **Lesson**: Always ensure module outputs exist before referencing them in other modules

**IAM Secrets Manager Permissions:**
- **Problem**: ECS tasks failed to start with `AccessDeniedException: secretsmanager:GetSecretValue`
- **Root cause**: `ecsTaskExecutionRole` didn't have permission to read Secrets Manager
- **Error appeared**: After task definition was deployed but before containers could start
- **Solution**: Added inline IAM policy granting `secretsmanager:GetSecretValue` on `webapp-dev-db-credentials-*`
- **Why this happened**: We added secrets to task definition but forgot to grant execution role permission
- **Lesson**: When injecting secrets into ECS, execution role needs explicit Secrets Manager permissions
- **IAM hierarchy reminder**: 
  - Execution role: Pulls images, writes logs, **reads secrets**
  - Task role: Application-level permissions inside the container

**Task Definition Not Deployed:**
- **Observation**: New task definition created but old tasks still running (revision 6)
- **Cause**: ECS service doesn't always automatically deploy new task definitions
- **Solution**: Force new deployment via ECS console or `aws ecs update-service --force-new-deployment`
- **Future improvement**: Consider adding deployment configuration to ensure updates happen automatically

### Key Learnings

**Terraform Architecture:**
- Module boundaries require careful planning to avoid circular dependencies
- CIDR-based security rules are simpler than security group references
- Always check dependency graphs before adding cross-module references
- Trade-offs exist between security granularity and module complexity

**Secrets Management:**
- Never hardcode credentials in code or configuration
- Secrets Manager provides encryption at rest and audit trail
- Random password generation should exclude problematic characters for connection strings
- Secret rotation requires Lambda function (prepared for but not implemented)

**RDS Operations:**
- RDS instance creation is slow (10-15+ minutes even for single-AZ)
- Multi-AZ adds 5-10 more minutes due to standby creation and synchronization
- Backup windows and maintenance windows should be scheduled during low-traffic periods
- Storage auto-scaling prevents running out of space without manual intervention
- gp3 storage offers better price/performance than gp2

**AWS Academy Constraints:**
- Always check free tier restrictions before designing infrastructure
- Error messages clearly indicate when hitting free tier limits
- Need to adapt production-grade designs for educational environment constraints
- Important to document what you would do differently in production

**ECS + Secrets Manager Integration:**
- Task definition supports two ways to inject values: `environment` (plain text) and `secrets` (from Secrets Manager)
- Secrets use special ARN format: `secret-arn:json-key::`
- ECS retrieves secrets at container startup, not at task definition creation
- Execution role needs `secretsmanager:GetSecretValue`, not task role

**CI/CD Pipeline Debugging:**
- GitHub Actions logs show full Terraform output for troubleshooting
- Validation errors appear before apply (caught circular dependency early)
- Apply errors show detailed AWS API responses
- Important to check AWS Console to verify infrastructure state matches expectations

### What's Running

**Database:**
- RDS endpoint: `webapp-dev-db-20260121052114655800000001.cah2gxfsybhq.us-east-1.rds.amazonaws.com`
- Database name: `appdb`
- Master user: `dbadmin`
- Password: Stored in Secrets Manager secret `webapp-dev-db-credentials-*`
- Port: 5432
- Engine: PostgreSQL 15.x (latest minor version)

**Secrets:**
- Secret ARN: In Secrets Manager
- Contains: username, password, engine, port, dbname in JSON format
- Encryption: KMS (AWS managed key)

**ECS Tasks:**
- Task definition revision: 7+ (with database environment variables)
- Environment variables injected: DB_HOST, DB_PORT, DB_NAME
- Secrets injected: DB_USERNAME, DB_PASSWORD
- Tasks can now connect to PostgreSQL database

### Cost Impact

Phase 3 additions (if running 24/7):
- RDS db.t3.micro: ~$0.017/hour = ~$12-15/month
- Secrets Manager: $0.40/month per secret
- Additional CloudWatch logs: ~$1/month
- **Total Phase 3 cost**: ~$13-16/month
- **Combined infrastructure**: ~$55-75/month (if running continuously)

Recommendation: Continue using destroy/rebuild strategy to minimize costs during development.

## Project Status - Ready for Phase 4 (Optional)

**Completed Phases:**
-  Phase 1: Multi-AZ VPC, ALB, ECS Fargate
-  Phase 2: Auto-scaling, CloudWatch monitoring, SNS alerts, remote state, CI/CD
-  Phase 3: Secrets Manager, RDS PostgreSQL, secure credential injection

**Current Architecture:**
```
Internet 
  ↓
Application Load Balancer (Multi-AZ, public subnets)
  ↓
ECS Fargate Tasks (1-10 tasks, auto-scaling, private subnets)
  ↓
RDS PostgreSQL (Single-AZ, private subnets)
  ↑
Secrets Manager (credentials)
  ↓
CloudWatch (metrics, logs, alarms) → SNS → Email
```

**Infrastructure Details:**
- Region: us-east-1
- Project: webapp
- Environment: dev
- State: Remote (S3 + DynamoDB locking)
- Deployment: Automated via GitHub Actions

**What Makes This Production-Grade:**
- High availability at application layer (multi-AZ, auto-scaling)
- Secure credential management (Secrets Manager, no hardcoded passwords)
- Comprehensive monitoring and alerting
- Infrastructure as Code with version control
- Automated CI/CD deployment pipeline
- Proper network isolation (public/private subnet separation)
- Encryption at rest (RDS, secrets)
- Automated backups with point-in-time recovery

**Potential Phase 4 Enhancements:**
- HTTPS with ACM certificate and Route53 custom domain
- WAF for application-layer security
- Secret rotation Lambda function
- Cross-region disaster recovery
- Container image vulnerability scanning
- X-Ray distributed tracing
- Custom CloudWatch dashboards
- Multi-region deployment

**Interview Readiness:**
This project demonstrates all core Junior SRE competencies:
- Infrastructure as Code (Terraform modules, remote state)
- CI/CD automation (GitHub Actions)
- High availability design (multi-AZ, auto-scaling)
- Observability (metrics, logs, alarms)
- Security best practices (secrets management, network isolation, encryption)
- Database operations (RDS, backups, maintenance windows)
- Problem-solving (circular dependencies, IAM permissions, free tier constraints)
- Cost optimization (destroy when not in use, appropriate instance sizing)