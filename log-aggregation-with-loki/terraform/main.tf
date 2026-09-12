terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "ssh_pub_key" { type = string }
variable "instance_type" { type = string, default = "t3.medium" }

resource "aws_security_group" "loki" {
  name        = "loki-sg"
  description = "Security group for Loki log aggregation server"
  vpc_id      = var.vpc_id

  ingress {
    description = "Loki HTTP API"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "Loki gRPC"
    from_port   = 9095
    to_port     = 9095
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "loki" {
  key_name   = "loki-deploy-key"
  public_key = var.ssh_pub_key
}

resource "aws_instance" "loki" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  key_name               = aws_key_pair.loki.key_name
  vpc_security_group_ids = [aws_security_group.loki.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = { Name = "loki-server", Role = "log-aggregation" }
}

output "loki_private_ip" { value = aws_instance.loki.private_ip }
output "loki_endpoint"   { value = "http://${aws_instance.loki.private_ip}:3100" }
output "loki_instance_id" { value = aws_instance.loki.id }