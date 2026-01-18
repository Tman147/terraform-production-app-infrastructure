# Changelog

All notable changes to this project will be documented in this file.

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
- Reduced ECS task CPU/memory for cost optimization

## [0.1.0] - 2025-01-18

### Added
- Project initialization
- Basic Terraform structure