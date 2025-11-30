// Select available AZ in the region
data "aws_availability_zones" "available" {
  state = "available"
}

// VPC for the EKS cluster
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.5"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_support   = true
  enable_dns_hostnames = true
}

// EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.10"

  name    = var.cluster_name
  kubernetes_version = var.eks_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      instance_types = [var.node_instance_type]
      capacity_type  = "SPOT" // in prod use ON_DEMAND
    }
  }
}
