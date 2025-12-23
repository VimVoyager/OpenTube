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

# VPC (using default for simplicity, can be customized)
data "aws_vpc" "default" {
  default = true
}

# EC2 Instance
resource "aws_instance" "opentube" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.opentube.key_name

  vpc_security_group_ids = [aws_security_group.opentube.id]

  # Increased storage for Docker images and logs
  root_block_device {
    volume_size           = 30  # GB
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name = "${var.project_name}-server"
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
