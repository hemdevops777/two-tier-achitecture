# Define provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-2"
}

# VPC
resource "aws_vpc" "vpc_block" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "vpc_block"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "ig" {
  tags = {
    Name = "ig"
  }
  vpc_id = aws_vpc.vpc_block.id
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc_block.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
  tags = {
    Name = "public_rt"
  }
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet1.id
  tags = {
    Name = "nat_gw"
  }
}

# Route Table for Private Subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc_block.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "private_rt"
  }
}

# Public Subnet 1
resource "aws_subnet" "public_subnet1" {
  tags = {
    Name = "public_subnet1"
  }
  vpc_id            = aws_vpc.vpc_block.id
  cidr_block        = var.public_subnet1
  availability_zone = "us-east-2a"
}

# Public Subnet 2
resource "aws_subnet" "public_subnet2" {
  tags = {
    Name = "public_subnet2"
  }
  vpc_id            = aws_vpc.vpc_block.id
  cidr_block        = var.public_subnet2
  availability_zone = "us-east-2b"
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public_assoc1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Subnet 1
resource "aws_subnet" "private_subnet1" {
  tags = {
    Name = "private_subnet1"
  }
  vpc_id            = aws_vpc.vpc_block.id
  cidr_block        = var.private_subnet1
  availability_zone = "us-east-2a"
}

# Private Subnet 2
resource "aws_subnet" "private_subnet2" {
  tags = {
    Name = "private_subnet2"
  }
  vpc_id            = aws_vpc.vpc_block.id
  cidr_block        = var.private_subnet2
  availability_zone = "us-east-2b"
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private_assoc1" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc2" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_rt.id
}

# Create EC2 instance in public subnet 1
resource "aws_instance" "EC2-1" {
  ami                         = var.ec2_instance_ami
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet1.id
  associate_public_ip_address = true
  count                       = 1
}

# Create EC2 instance in public subnet 2
resource "aws_instance" "EC2_2" {
  ami                         = var.ec2_instance_ami
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet2.id
  associate_public_ip_address = true
  count                       = 1
}

# Create RDS instance
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.37"
  instance_class       = "db.m5d.large"
  db_name              = "two_tier_db"
  username             = var.db_username
  password             = var.db_password
  skip_final_snapshot  = true
}

# Create RDS Subnet Group
resource "aws_db_subnet_group" "default" {
  name       = "rds default"
  subnet_ids = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
  tags = {
    Name = "default"
  }
}

# Elastic Load Balancer
resource "aws_lb" "LB" {
  name               = "two-tier-LB"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
  enable_deletion_protection = false
  tags = {
    Environment = "production"
  }
}
