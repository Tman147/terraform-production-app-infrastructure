# ==============================================================================
# VPC - Your Private Network in AWS
# ==============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Allows resources to get DNS names
  enable_dns_support   = true  # Enables DNS resolution

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - resource "aws_vpc" "main" → Creates a VPC, we'll call it "main" in our code
# - cidr_block → The IP range for this VPC
# - enable_dns_* → Lets resources talk to each other by name, not just IP
# - tags → Labels for organization (helpful in AWS console)
# - ${var.vpc_cidr} → Inserts the value from variables.tf

# ==============================================================================
# Internet Gateway - Door to the Internet
# ==============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Attaches to our VPC
# - Allows resources in public subnets to reach internet
# - aws_vpc.main.id → References the VPC we created above
#   (Terraform knows to create VPC first, then IGW)

# ==============================================================================
# Public Subnets - Where Internet-Facing Resources Live
# ==============================================================================

resource "aws_subnet" "public" {
  count = length(var.availability_zones)  # Creates 2 subnets (one per AZ)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true  # Auto-assign public IPs

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
    Type        = "Public"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - count = 2 → Creates 2 subnets
# - count.index → 0 for first subnet, 1 for second
# - cidr_block calculation:
#   - count.index = 0 → "10.0.1.0/24"
#   - count.index = 1 → "10.0.2.0/24"
# - map_public_ip_on_launch → Resources here get public IPs automatically

# ==============================================================================
# Private Subnets - Where Apps and Databases Live
# ==============================================================================

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 11}.0/24"  # 10.0.11.0, 10.0.12.0
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-${var.availability_zones[count.index]}"
    Type        = "Private"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Similar to public subnets
# - count.index + 11 → Different IP range (10.0.11.x, 10.0.12.x)
# - No map_public_ip_on_launch → These stay private

# ==============================================================================
# NAT Gateway - Allows Private Subnets to Reach Internet (Outbound Only)
# ==============================================================================

# First, we need an Elastic IP for the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"  # This EIP is for use in a VPC

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_internet_gateway.main]
}

# EXPLANATION:
# - EIP = Elastic IP = Static public IP address
# - NAT Gateway needs a public IP to work
# - depends_on → Terraform won't create this until IGW exists

# Now create the NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # Put in first public subnet

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_internet_gateway.main]
}

# EXPLANATION:
# - NAT = Network Address Translation
# - Lets private subnet resources download updates, talk to AWS services
# - BUT prevents inbound connections from internet (security)
# - We only create 1 NAT Gateway to save costs (~$32/month)
#   (Production would have 1 per AZ for high availability)

# ==============================================================================
# Route Tables - Traffic Rules
# ==============================================================================

# Public Route Table - Routes to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"  # All internet traffic
    gateway_id = aws_internet_gateway.main.id  # Goes through IGW
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Type        = "Public"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Route table = Traffic rulebook
# - "0.0.0.0/0" = All IP addresses (the entire internet)
# - Rule: "If traffic is going to internet, send it through IGW"

# Private Route Table - Routes to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"  # All internet traffic
    nat_gateway_id = aws_nat_gateway.main.id  # Goes through NAT
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-rt"
    Type        = "Private"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EXPLANATION:
# - Private resources can reach internet through NAT
# - But internet cannot initiate connections back
# - One-way door (outbound only)

# ==============================================================================
# Route Table Associations - Connect Subnets to Route Tables
# ==============================================================================

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# EXPLANATION:
# - This is like assigning rules to rooms
# - "Public subnets: use public route table rules"
# - "Private subnets: use private route table rules"