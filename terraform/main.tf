data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu_2204" {
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

resource "aws_vpc" "cluster" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "mern-k8s-vpc" }
}

resource "aws_internet_gateway" "cluster" {
  vpc_id = aws_vpc.cluster.id
  tags   = { Name = "mern-k8s-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.cluster.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "mern-k8s-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.cluster.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster.id
  }
  tags = { Name = "mern-k8s-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "cluster" {
  name        = "mern-k8s-cluster"
  description = "Kubernetes lab nodes; restrict admin access with admin_cidr."
  vpc_id      = aws_vpc.cluster.id

  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "Kubernetes API from administrator"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "Demo frontend NodePort"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Grafana dashboard from administrator"
    from_port   = 30300
    to_port     = 30300
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "Cluster node-to-node traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "mern-k8s-cluster" }
}

locals {
  nodes = {
    "k8s-control" = "control-plane"
    "k8s-worker1" = "worker"
    "k8s-worker2" = "worker"
  }
}

resource "aws_instance" "node" {
  for_each                    = local.nodes
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  key_name                    = var.ssh_key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.cluster.id]
  associate_public_ip_address = true
  root_block_device {
    volume_size = 40
    volume_type = "gp3"
    encrypted   = true
  }
  tags = {
    Name = "mern-${each.key}"
    Role = each.value
  }
}
