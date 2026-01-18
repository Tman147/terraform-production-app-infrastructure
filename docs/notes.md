# Development Notes

## 2025-01-16 - Initial Setup

Started with networking module. Key decision: using NAT gateway instead of NAT instance for better reliability, even though it costs more (~$32/month vs ~$5/month).

## 2025-01-18 - IAM Issues

Hit IAM permissions error - lab account doesn't allow `iam:CreateRole`. Fixed by using data source to reference existing `ecsTaskExecutionRole`. Good reminder that enterprise environments often have restricted permissions.

## 2025-01-18 - ECS Configuration

Chose Fargate over EC2 launch type:
- Pros: No instance management, pay per task
- Cons: Slightly more expensive, less control
- For this project: Fargate makes sense (simplicity > cost)

Set task size to 0.25 vCPU / 512MB - smallest option. Good for demo/learning. Production would need load testing to determine right size.

## 2025-01-18 - Security Groups

Important lesson: Security groups are stateful - return traffic allowed automatically. Only need to define inbound rules for request traffic.

ALB → ECS rule uses security group reference (not CIDR) - better than hardcoding IPs since it dynamically allows from ALB even if ALB IPs change.