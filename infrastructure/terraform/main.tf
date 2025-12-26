terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSH Key Pair
resource "aws_key_pair" "opentube" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# VPC
resource "aws_vpc" "opentube" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "opentube" {
  vpc_id = aws_vpc.opentube.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "opentube_public" {
  vpc_id                  = aws_vpc.opentube.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "opentube_public" {
  vpc_id = aws_vpc.opentube.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.opentube.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "opentube_public" {
  subnet_id      = aws_subnet.opentube_public.id
  route_table_id = aws_route_table.opentube_public.id
}

# EC2 Instance
resource "aws_instance" "opentube" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.opentube.key_name
  subnet_id     = aws_subnet.opentube_public.id

  vpc_security_group_ids = [aws_security_group.opentube.id]

  # Increased storage for Docker images and logs
  root_block_device {
    volume_size           = 30  # GB
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name    = "${var.project_name}-server"
    Project = var.project_name
  }

  # Ensure proper initialization
  user_data_replace_on_change = true
}

# Elastic IP (static IP address)
resource "aws_eip" "opentube" {
  instance = aws_instance.opentube.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}