variable "aws_region" {
  description = "AWS region for the Ubuntu 22.04 Kubernetes lab."
  type        = string
  default     = "ap-south-1"
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair name."
  type        = string
}

variable "admin_cidr" {
  description = "Your public IPv4 CIDR for SSH and Kubernetes API access (for example, 203.0.113.10/32)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type used for each Kubernetes VM."
  type        = string
  default     = "t3.medium"
}
