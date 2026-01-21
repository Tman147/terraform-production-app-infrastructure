# AWS Production Infrastructure with Terraform

A production-ready AWS infrastructure deployment using Terraform, featuring load-balanced containerized applications with high availability, auto-scaling, comprehensive monitoring, database integration, and automated CI/CD deployments.

## What This Project Does

Deploys a complete AWS infrastructure stack including:
- Multi-AZ VPC with public/private subnet separation
- Application Load Balancer for traffic distribution
- ECS Fargate for container orchestration with auto-scaling
- RDS PostgreSQL database in private subnets
- AWS Secrets Manager for secure credential storage
- CloudWatch monitoring with alarms and SNS notifications
- Remote state management with S3 and DynamoDB
- Automated deployments via GitHub Actions CI/CD pipeline
- Security groups configured for least-privilege access

## Architecture

The infrastructure spans two availability zones for high availability:
```
Internet → ALB (public subnets) → ECS Tasks (private subnets) → RDS PostgreSQL (private subnets)
                                          ↓                              ↑
                                   Auto-Scaling Group              Secrets Manager
                                          ↓
                                  CloudWatch Alarms → SNS → Email
```

**Key design decisions:**
- **Multi-AZ deployment**: Application layer survives single AZ failure
- **Private subnets for workloads**: Containers and database not directly internet-accessible
- **NAT Gateway**: Allows private subnet outbound connectivity (chose reliability over NAT instance cost savings)
- **Security groups**: Layered security with CIDR-based database access rules
- **Auto-scaling**: Target tracking based on CPU (70%) and memory (80%) utilization
- **Observability-first**: Comprehensive CloudWatch monitoring before issues impact users
- **Secrets management**: Database credentials never in code, encrypted at rest
- **Remote state**: S3 + DynamoDB for team collaboration and state locking
- **Automation**: GitHub Actions eliminates manual deployment toil

## Technologies Used

- **Terraform**: Infrastructure as Code
- **AWS Services**: VPC, ECS Fargate, ALB, RDS PostgreSQL, Secrets Manager, CloudWatch, SNS, S3, DynamoDB, IAM
- **Docker**: nginx container (demo application)
- **GitHub Actions**: CI/CD automation
- **Git**: Version control and collaboration

## Project Status

### ✅ Phase 1: Core Infrastructure (Completed)
- Multi-AZ VPC with public/private subnets
- Application Load Balancer with health checks
- ECS Fargate service
- CloudWatch logging
- Security groups and IAM roles

### ✅ Phase 2: Scaling & Observability (Completed)
- Auto-scaling policies (CPU and memory target tracking)
- CloudWatch metrics and alarms (5 critical alerts)
- SNS email notifications
- Remote state management (S3 + DynamoDB)
- GitHub Actions CI/CD pipeline
- IAM policy consolidation

### ✅ Phase 3: Secrets & Database (Completed)
- AWS Secrets Manager for credential storage with KMS encryption
- RDS PostgreSQL 15 (single-AZ for AWS Academy free tier)
- Automated backups (1-day retention)
- Secure ECS → RDS connectivity via environment variables and secrets injection
- IAM permissions for ECS to read Secrets Manager

### 🚧 Phase 4: Advanced Features (Future)
- HTTPS with ACM certificate
- Custom domain with Route53
- WAF (Web Application Firewall)
- Secret rotation with Lambda
- Container image scanning
- Multi-region disaster recovery

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with permissions for VPC, ECS, ALB, RDS, Secrets Manager, IAM, CloudWatch, S3, DynamoDB
- Git and GitHub account (for CI/CD pipeline)

**Note**: If using AWS Academy or restricted AWS account, you may need to adjust:
- RDS Multi-AZ settings (free tier may require single-AZ)
- Backup retention period (free tier maximum is 1 day)
- PostgreSQL version (use flexible version number like "15" instead of specific minor versions)

## Deployment

### Option 1: Automated Deployment (Recommended)

**Using GitHub Actions** - Infrastructure deploys automatically on push to `main` branch:

1. **Fork/clone the repository**
```bash
   git clone https://github.com/Tman147/terraform-production-app-infrastructure.git
   cd terraform-production-app-infrastructure
```

2. **Configure GitHub Secrets**
   
   Add to repository Settings → Secrets and variables → Actions:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN` (if using temporary credentials)

3. **Push to trigger deployment**
```bash
   git add .
   git commit -m "Deploy infrastructure"
   git push origin main
```

4. **Monitor deployment**
   
   Check the Actions tab in GitHub to watch the workflow progress.
   - Networking, secrets, application: ~5 minutes
   - RDS database creation: ~10-15 minutes additional
   - Total deployment time: ~15-20 minutes

**Trigger rebuild without code changes:**
```bash
git commit --allow-empty -m "Rebuild infrastructure"
git push
```

### Option 2: Manual Deployment

1. **Initialize Terraform**
```bash
   terraform init
```

2. **Review the plan**
```bash
   terraform plan
```

3. **Apply the configuration**
```bash
   terraform apply
```
   Type `yes` when prompted.

4. **Access the application**
   
   After deployment completes, Terraform will output the application URL:
```
   application_url = "http://webapp-dev-alb-xxxxxxxxxx.us-east-1.elb.amazonaws.com"
```
   
   **Note**: Wait 2-3 minutes for ECS tasks to become healthy before accessing.

## Monitoring & Alerts

### CloudWatch Alarms

The infrastructure includes 5 critical alarms that notify via email (SNS):

| Alarm | Threshold | What It Monitors |
|-------|-----------|------------------|
| High CPU | > 80% for 2 min | Container CPU utilization |
| High Memory | > 80% for 2 min | Container memory utilization |
| High 5xx Errors | > 10 errors in 5 min | Application failures |
| Slow Response Time | > 1 second avg for 5 min | User experience degradation |
| Unhealthy Hosts | < 1 healthy host for 1 min | Service availability |

**Setup**: Confirm SNS subscription in your email after first deployment.

### Auto-Scaling Behavior

- **Scale Out**: Adds tasks when CPU > 70% or Memory > 80%
- **Scale In**: Removes tasks when utilization drops below target
- **Limits**: Min 1 task, Max 10 tasks (configurable)
- **Cooldown**: Prevents rapid scaling oscillation

## Database

### RDS PostgreSQL Configuration

- **Engine**: PostgreSQL 15 (latest minor version)
- **Instance**: db.t3.micro (free tier eligible)
- **Storage**: 20GB gp3 encrypted, auto-scales to 100GB
- **Deployment**: Single-AZ (AWS Academy constraint) or Multi-AZ (production)
- **Backups**: 1-day retention (free tier) or 7 days (production)
- **Network**: Private subnets only, not publicly accessible
- **Security**: CIDR-based security group (allows access from private subnets)

### Database Credentials

Credentials are securely managed via AWS Secrets Manager:
- **Secret Name**: `webapp-dev-db-credentials-*`
- **Storage**: JSON format with username, password, engine, port, dbname
- **Encryption**: KMS (AWS managed key)
- **Access**: ECS tasks read secrets at runtime via IAM permissions
- **Never**: Credentials never appear in code, logs, or Terraform state

### Connecting to Database

ECS containers receive these environment variables:
- `DB_HOST`: RDS endpoint hostname
- `DB_PORT`: PostgreSQL port (5432)
- `DB_NAME`: Database name (appdb)
- `DB_USERNAME`: From Secrets Manager (dbadmin)
- `DB_PASSWORD`: From Secrets Manager (randomly generated)

## State Management

Infrastructure state is stored remotely for collaboration and safety:

- **S3 Bucket**: `webapp-terraform-state-930056746901`
  - Versioning enabled for rollback capability
  - Server-side encryption (SSE-S3)
  
- **DynamoDB Table**: `webapp-terraform-locks`
  - Prevents concurrent Terraform operations
  - Ensures state consistency

**Benefits**: Team collaboration, audit trail, disaster recovery

## Cleanup

To destroy all resources and stop AWS charges:
```bash
terraform destroy
```

**⚠️ Warning**: This will delete:
- RDS database (unless deletion protection enabled)
- All application data
- Backup snapshots (if skip_final_snapshot = true)

**Cost optimization strategy**: Destroy infrastructure when not actively working. Rebuild takes ~15-20 minutes via GitHub Actions automation.

## Cost Estimate

Running 24/7 in AWS Academy / Free Tier:
- NAT Gateway: ~$32/month
- Application Load Balancer: ~$16/month
- ECS Fargate (1-10 tasks, 0.25 vCPU, 512MB): ~$5-50/month (scales with load)
- RDS db.t3.micro (single-AZ): ~$12-15/month
- CloudWatch: ~$1/month
- S3 + DynamoDB (state): < $1/month
- Secrets Manager: ~$0.40/month
- **Total: ~$66-115/month** (depending on auto-scaling activity)

**Production with Multi-AZ RDS**: ~$90-140/month

**Recommended**: Use `terraform destroy` when not actively using to minimize costs.

## Project Structure
```
├── main.tf                 # Root module configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── backend.tf              # Remote state configuration (S3 + DynamoDB)
├── modules/
│   ├── networking/         # VPC, subnets, routing, NAT Gateway
│   ├── application/        # ECS, ALB, security groups
│   ├── secrets/            # AWS Secrets Manager for database credentials
│   ├── database/           # RDS PostgreSQL configuration
│   ├── monitoring/         # CloudWatch alarms, SNS topics
│   └── autoscaling/        # ECS auto-scaling policies
├── .github/
│   └── workflows/
│       └── terraform.yml   # CI/CD pipeline
├── notes.md                # Development decisions and lessons learned
├── CHANGELOG.md            # Version history
└── README.md               # This file
```

## Challenges Solved

### IAM Permissions in Lab Environment

Initial deployment failed due to IAM role creation restrictions. Solved by using Terraform data sources to reference existing `ecsTaskExecutionRole` instead of creating new roles.

**Lesson learned**: Always check account permissions and adapt infrastructure code accordingly. Using data sources for existing resources is a common pattern in restricted environments.

### Consolidated IAM Policies

Replaced multiple AWS managed policy attachments with a single comprehensive custom policy combining ECS, ECR, CloudWatch, S3, DynamoDB, EC2, ELB, and Secrets Manager permissions. Cleaner approach that works within lab account constraints.

**Phase 3 Addition**: Added `secretsmanager:GetSecretValue` permission to ECS execution role to allow containers to read database credentials.

### Remote State Migration

Successfully migrated from local state to S3 backend with DynamoDB locking. Enabled team collaboration and prevented concurrent modification issues.

### CI/CD Authentication

Configured GitHub Actions with AWS credentials stored as repository secrets. Workflow automatically validates, plans, and applies Terraform changes on push to main branch.

### Circular Dependency (Phase 3)

**Problem**: Database module needed ECS security group ID, but application module needed database outputs.

**Solution**: Used CIDR-based security rules instead of security group references. Database security group allows traffic from private subnet CIDR blocks (10.0.11.0/24, 10.0.12.0/24) instead of referencing ECS security group.

**Trade-off**: Allows any resource in private subnets to access database (not just ECS). Acceptable because private subnets are fully controlled and have no internet gateway.

### AWS Academy Free Tier Restrictions (Phase 3)

**Encountered limitations:**
- PostgreSQL 15.4 not available → Used flexible version "15"
- 7-day backup retention exceeded limit → Reduced to 1 day
- Multi-AZ deployment not allowed → Disabled for free tier

**Lesson**: Always check free tier restrictions before designing infrastructure. Document production-ready configurations separately.

### ECS Secrets Manager Permissions (Phase 3)

**Problem**: ECS tasks failed with `AccessDeniedException: secretsmanager:GetSecretValue`

**Cause**: Task execution role didn't have permission to read secrets.

**Solution**: Added inline IAM policy granting `secretsmanager:GetSecretValue` on `webapp-dev-db-credentials-*` secrets.

**Lesson**: When injecting secrets into ECS tasks, execution role needs explicit Secrets Manager permissions.

## Troubleshooting

### ECS Tasks Fail to Start with Secrets Error

**Symptom**: Tasks stop immediately with error about `secretsmanager:GetSecretValue`

**Solution**: 
1. Go to IAM → Roles → `ecsTaskExecutionRole`
2. Add inline policy with `secretsmanager:GetSecretValue` permission
3. Force new ECS service deployment

### Environment Variables Not Showing in ECS Tasks

**Symptom**: Task definition updated but running tasks don't have DB environment variables

**Solution**:
1. ECS Console → Clusters → Service
2. Click "Update service" → Check "Force new deployment"
3. Wait 2-3 minutes for new tasks to start

### RDS Creation Takes Too Long

**Expected**: RDS instance creation takes 10-15 minutes for single-AZ, 15-20 minutes for Multi-AZ. This is normal AWS behavior.

### GitHub Actions Validation Fails

**Check**:
- Ensure all module outputs are defined before referencing them
- Verify circular dependencies aren't present
- Check Terraform syntax with `terraform validate` locally

## What I Learned

### Technical Skills
- Terraform module design and reusability
- AWS networking fundamentals (VPC, subnets, routing, NAT)
- ECS Fargate container orchestration
- RDS database operations and configuration
- Application Load Balancer configuration and health checks
- Security group design for layered security
- AWS Secrets Manager integration with ECS
- CloudWatch logging, metrics, and alarms
- Auto-scaling policies (target tracking)
- SNS notification configuration
- Remote state management (S3 + DynamoDB locking)
- GitHub Actions workflow design
- Working within AWS permission constraints and free tier limitations

### SRE Principles
- **High Availability**: Multi-AZ architecture survives zone failures
- **Observability**: "You can't manage what you don't measure" - monitoring before incidents
- **Automation**: CI/CD eliminates manual deployment toil and human error
- **Infrastructure as Code**: Version-controlled, repeatable, testable infrastructure
- **Security**: Secrets management, encryption at rest, network isolation
- **Cost Optimization**: Balance reliability with budget constraints
- **Problem-Solving**: Breaking circular dependencies, adapting to constraints

### Architecture Decisions
- CIDR-based security rules vs security group references (simplicity vs granularity)
- Single-AZ vs Multi-AZ deployment (cost vs high availability)
- NAT Gateway vs NAT instance (reliability vs cost)
- Secrets Manager vs Parameter Store (rotation capability, audit trail)
- Module boundaries and dependency management

## Future Enhancements

### Phase 4 (Potential)
- [ ] HTTPS with ACM certificate and HTTP → HTTPS redirect
- [ ] Custom domain with Route53
- [ ] CloudFront CDN for global content delivery
- [ ] WAF (Web Application Firewall) for security
- [ ] Lambda function for automatic secret rotation
- [ ] Container image vulnerability scanning
- [ ] X-Ray distributed tracing
- [ ] Custom CloudWatch dashboards
- [ ] Multi-region deployment for disaster recovery
- [ ] Blue/green deployment strategy
- [ ] RDS read replicas for read scaling
- [ ] ElastiCache for caching layer

## Contributing

This is a learning project, but feedback and suggestions are welcome! Please open an issue or submit a pull request.

## License

MIT

## Author

Trevor Davis  
Strategic Solutions Engineer → Aspiring SRE  
Building production-grade infrastructure with Infrastructure as Code

## Acknowledgments

Built as part of my journey transitioning into Site Reliability Engineering. This project demonstrates core SRE competencies: reliability engineering, observability, automation, security, and infrastructure as code.

**Key learning outcomes:**
- Designed and deployed production-grade AWS infrastructure
- Implemented comprehensive monitoring and auto-scaling
- Integrated secure database with credential management
- Built automated CI/CD pipeline
- Solved real-world challenges (circular dependencies, IAM permissions, free tier constraints)
- Documented architecture decisions and trade-offs