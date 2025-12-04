locals {
  # Define availability zones
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Match AZs length
  private_subnets = slice(var.private_subnets, 0, length(local.azs))
  public_subnets  = slice(var.public_subnets, 0, length(local.azs))

  # Tags definition
  default_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

// Fetch available AZ in the region
data "aws_availability_zones" "available" {
  state = "available"
}

// VPC for the EKS cluster
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.5"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.default_tags,
    { Name = "${var.project_name}-vpc" }
  )
}

// EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.10"

  name               = "${var.project_name}-cluster"
  kubernetes_version = var.eks_version

  // Attach control plane and worker nodes to VPC
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  // Public endpoint access for dev/test env
  endpoint_public_access  = true
  endpoint_private_access = true

  // Grant cluster-admin rights to the caller identity
  enable_cluster_creator_admin_permissions = true

  // Enable IRSA for secure pod-to-AWS access
  enable_irsa = true

  // Required addons on EKS 1.30+ with module v21.x
  addons = {
    coredns    = {}
    kube-proxy = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    vpc-cni = {
      before_compute = true
    }
  }

  // EKS Managed Node Group
  eks_managed_node_groups = {
    default = {
      // Stable AMI for EKS 1.30+
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance_type]

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      capacity_type = "SPOT" // cost-saving; use ON_DEMAND in prod

      tags = merge(
        local.default_tags,
        { Name = "${var.project_name}-node" }
      )
    }
  }

  tags = merge(
    local.default_tags,
    { Name = "${var.project_name}-cluster" }
  )
}
