# AWS Production Infrastructure with Terraform

A production-ready AWS infrastructure deployment using Terraform, featuring load-balanced containerized applications with high availability, auto-scaling, comprehensive monitoring, and automated CI/CD deployments.

## What This Project Does

Deploys a complete AWS infrastructure stack including:
- Multi-AZ VPC with public/private subnet separation
- Application Load Balancer for traffic distribution
- ECS Fargate for container orchestration with auto-scaling
- CloudWatch monitoring with alarms and SNS notifications
- Remote state management with S3 and DynamoDB
- Automated deployments via GitHub Actions CI/CD pipeline
- Security groups configured for least-privilege access

## Architecture

The infrastructure spans two availability zones for high availability:
```
Internet → ALB (public subnets) → ECS Tasks (private subnets) → CloudWatch Logs/Metrics
                                          ↓
                                   Auto-Scaling Group
                                          ↓
                                  CloudWatch Alarms → SNS → Email
```

**Key design decisions:**
- **Multi-AZ deployment**: Survives single AZ failure
- **Private subnets for workloads**: Containers not directly internet-accessible
- **NAT Gateway**: Allows private subnet outbound connectivity (chose reliability over NAT instance cost savings)
- **Security groups**: Layered security (ALB → ECS only, using SG references not CIDR blocks)
- **Auto-scaling**: Target tracking based on CPU (70%) and memory (80%) utilization
- **Observability-first**: Comprehensive CloudWatch monitoring before issues impact users
- **Remote state**: S3 + DynamoDB for team collaboration and state locking
- **Automation**: GitHub Actions eliminates manual deployment toil

## Technologies Used

- **Terraform**: Infrastructure as Code
- **AWS Services**: VPC, ECS Fargate, ALB, CloudWatch, SNS, S3, DynamoDB, IAM
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

### 🚧 Phase 3: Secrets & Database (Next)
- AWS Secrets Manager for credential storage
- RDS PostgreSQL Multi-AZ deployment
- Automated backups and secret rotation
- Secure ECS → RDS connectivity

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with permissions for VPC, ECS, ALB, IAM, CloudWatch, S3, DynamoDB
- Git and GitHub account (for CI/CD pipeline)

**Note**: If using a restricted/lab AWS account, you may need to modify IAM role creation. See `modules/application/main.tf` for data source approach.

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
- **Limits**: Min 1 task, Max 10 tasks
- **Cooldown**: Prevents rapid scaling oscillation

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

Or let GitHub Actions destroy via workflow (if configured).

**Cost optimization strategy**: Destroy infrastructure when not actively working. Rebuild takes ~10 minutes via GitHub Actions automation.

## Cost Estimate

Running 24/7:
- NAT Gateway: ~$32/month
- Application Load Balancer: ~$16/month
- ECS Fargate (1-10 tasks, 0.25 vCPU, 512MB): ~$5-50/month (scales with load)
- CloudWatch: ~$1/month
- S3 + DynamoDB (state): < $1/month
- **Total: ~$54-99/month** (depending on auto-scaling)

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

Replaced multiple AWS managed policy attachments with a single comprehensive custom policy combining ECS, ECR, CloudWatch, S3, DynamoDB, EC2, and ELB permissions. Cleaner approach that works within lab account constraints.

### Remote State Migration

Successfully migrated from local state to S3 backend with DynamoDB locking. Enabled team collaboration and prevented concurrent modification issues.

### CI/CD Authentication

Configured GitHub Actions with AWS credentials stored as repository secrets. Workflow automatically validates, plans, and applies Terraform changes on push to main branch.

## What I Learned

### Technical Skills
- Terraform module design and reusability
- AWS networking fundamentals (VPC, subnets, routing, NAT)
- ECS Fargate container orchestration
- Application Load Balancer configuration and health checks
- Security group design for layered security (SG references > CIDR blocks)
- CloudWatch logging and metrics
- Auto-scaling policies (target tracking)
- SNS notification configuration
- Remote state management (S3 + DynamoDB locking)
- GitHub Actions workflow design
- Working within AWS permission constraints

### SRE Principles
- **High Availability**: Multi-AZ architecture survives zone failures
- **Observability**: "You can't manage what you don't measure" - monitoring before incidents
- **Automation**: CI/CD eliminates manual deployment toil and human error
- **Infrastructure as Code**: Version-controlled, repeatable, testable infrastructure
- **Cost Optimization**: Balance reliability with budget constraints

## Future Enhancements

### Phase 3 (Next - In Progress)
- [ ] AWS Secrets Manager for credential storage
- [ ] RDS PostgreSQL Multi-AZ database
- [ ] Automated secret rotation
- [ ] Database backups and point-in-time recovery

### Phase 4 (Future)
- [ ] HTTPS with ACM certificate and HTTP → HTTPS redirect
- [ ] Custom domain with Route53
- [ ] CloudFront CDN for global content delivery
- [ ] WAF (Web Application Firewall) for security
- [ ] Container image vulnerability scanning
- [ ] Multi-region deployment for disaster recovery
- [ ] Blue/green deployment strategy
- [ ] Prometheus/Grafana for enhanced observability

## Contributing

This is a learning project, but feedback and suggestions are welcome! Please open an issue or submit a pull request.

## License

MIT

## Author

Trevor Davis  
Strategic Solutions Engineer → Aspiring SRE  
Building production-grade infrastructure with IaC

## Acknowledgments

Built as part of my journey transitioning into Site Reliability Engineering. This project demonstrates core SRE competencies: reliability engineering, observability, automation, and infrastructure as code.