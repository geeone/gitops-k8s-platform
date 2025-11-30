// AWS provider configuration
provider "aws" {
  region = var.aws_region
}

// EKS cluster info (for dynamic configuration of providers)
data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

// Kubernetes provider (for direct resource management by Helm/Flux)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

// Helm provider (for HelmRelease installs)
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

// Flux provider (for GitOps bootstrap)
provider "flux" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }

  // Git repository for Flux (SSH)
  git = {
    url = "ssh://git@github.com/geeone/gitops-k8s-platform.git"

    ssh = {
      username    = "git"
      private_key = file("${path.module}/flux-id-ed25519")
    }
  }
}
