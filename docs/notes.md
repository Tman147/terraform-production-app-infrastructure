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

Created CloudWatch alerts for monitoring - High CPU, High Memory, High 5xx error, and slow response times, and unhealthy host. 

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