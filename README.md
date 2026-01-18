# AWS Production Infrastructure with Terraform

A production-ready AWS infrastructure deployment using Terraform, featuring load-balanced containerized applications with high availability.

## What This Project Does

Deploys a complete AWS infrastructure stack including:
- Multi-AZ VPC with public/private subnet separation
- Application Load Balancer for traffic distribution
- ECS Fargate for container orchestration
- CloudWatch for logging and monitoring
- Security groups configured for least-privilege access

## Architecture

The infrastructure spans two availability zones for high availability:
```
Internet → ALB (public subnets) → ECS Tasks (private subnets) → CloudWatch Logs
```

**Key design decisions:**
- **Multi-AZ deployment**: Survives single AZ failure
- **Private subnets for workloads**: Containers not directly internet-accessible
- **NAT Gateway**: Allows private subnet outbound connectivity
- **Security groups**: Layered security (ALB → ECS only)

## Technologies Used

- **Terraform**: Infrastructure as Code
- **AWS Services**: VPC, ECS Fargate, ALB, CloudWatch, IAM
- **Docker**: nginx container (demo application)

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with permissions for VPC, ECS, ALB, IAM

**Note**: If using a restricted/lab AWS account, you may need to modify IAM role creation. See `modules/application/main.tf` for data source approach.

## Deployment

1. **Clone the repository**
```bash
   git clone https://github.com/Tman147/terraform-production-app-infrastructure.git
   cd terraform-production-app-infrastructure
```

2. **Initialize Terraform**
```bash
   terraform init
```

3. **Review the plan**
```bash
   terraform plan
```

4. **Apply the configuration**
```bash
   terraform apply
```
   Type `yes` when prompted.

5. **Access the application**
   
   After deployment completes, Terraform will output the application URL:
```
   application_url = "http://webapp-dev-alb-xxxxxxxxxx.us-east-1.elb.amazonaws.com"
```
   
   **Note**: Wait 2-3 minutes for ECS tasks to become healthy before accessing.

## Cleanup

To destroy all resources and stop AWS charges:
```bash
terraform destroy
```

## Cost Estimate

Running 24/7:
- NAT Gateway: ~$32/month
- Application Load Balancer: ~$16/month
- ECS Fargate (2 tasks, 0.25 vCPU, 512MB): ~$11/month
- **Total: ~$59/month**

For learning/testing, use `terraform destroy` when not actively using to minimize costs.

## Project Structure
```
├── main.tf                 # Root module configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── modules/
│   ├── networking/         # VPC, subnets, routing
│   └── application/        # ECS, ALB, security groups
└── README.md              # This file
```

## Challenges Solved

**IAM Permissions in Lab Environment**

Initial deployment failed due to IAM role creation restrictions. Solved by using Terraform data sources to reference existing `ecsTaskExecutionRole` instead of creating new roles.

**Lesson learned**: Always check account permissions and adapt infrastructure code accordingly. Using data sources for existing resources is a common pattern in restricted environments.

## What I Learned

- Terraform module design and reusability
- AWS networking fundamentals (VPC, subnets, routing, NAT)
- ECS Fargate container orchestration
- Application Load Balancer configuration and health checks
- Security group design for layered security
- CloudWatch logging integration
- Working within AWS permission constraints

## Future Enhancements

Potential improvements:
- [ ] Add RDS database module
- [ ] Implement auto-scaling based on CPU/memory
- [ ] Add HTTPS with ACM certificate
- [ ] Set up custom domain with Route53
- [ ] Add CI/CD pipeline for automated deployments

## License

MIT

## Author

Trevor Davis