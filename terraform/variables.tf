variable "aws_region" {
  type        = string
  description = "AWS region to deploy EKS"
  default     = "eu-central-1"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "gitops-cluster"
}
