variable "aws_region" {
  type        = string
  description = "AWS region to deploy EKS"
  default     = "eu-central-1"
}

variable "project_name" {
  type        = string
  description = "Project name (Used as resources prefix)"
  default     = "gitops-eks"
}

variable "eks_version" {
  type        = string
  description = "Kubernetes version for EKS"
  default     = "1.33"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets for EKS worker nodes"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets for NAT/ingress"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "node_instance_type" {
  type        = string
  description = "Instance type for EKS managed node group"
  default     = "t3.medium"
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 2
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 4
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}
