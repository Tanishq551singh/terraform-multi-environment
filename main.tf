# ---------------------------------------------------------
# DATA SOURCES
# Discover existing AWS resources dynamically
# ---------------------------------------------------------

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Subnets inside the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Available Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_name]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}


# ---------------------------------------------------------
# SECURITY GROUP
# ---------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for ${var.environment} environment"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-sg"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}


# ---------------------------------------------------------
# EC2 INSTANCES
# ---------------------------------------------------------

resource "aws_instance" "app" {
  count = var.instance_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id = data.aws_subnets.default.ids[
    count.index % length(data.aws_subnets.default.ids)
  ]

  vpc_security_group_ids = [aws_security_group.ec2.id]

  tags = {
    Name        = "${var.project_name}-${var.environment}-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}


# ---------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------

output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.app[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses of EC2 instances"
  value       = aws_instance.app[*].public_ip
}

output "availability_zones" {
  description = "Available AWS availability zones"
  value       = data.aws_availability_zones.available.names
}

output "vpc_id" {
  description = "VPC used by the environment"
  value       = data.aws_vpc.default.id
}

output "instance_names" {
  description = "Names of EC2 instances"
  value = [
    for instance in aws_instance.app :
    instance.tags["Name"]
  ]
}

output "project_info" {
  description = "Project and environment information"
  value = {
    project     = var.project_name
    environment = var.environment
    region      = var.region
    instances   = var.instance_count
  }
}