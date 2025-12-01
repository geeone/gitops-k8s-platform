// AWS provider
provider "aws" {
  region = var.aws_region
}

// EKS cluster metadata
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

// Kubernetes provider (talks to the EKS API server)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

// Helm provider (for Helm charts installs)
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

// Flux provider (uses EKS + Git over SSH)
provider "flux" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }

  // GitHub repo with Flux manifests
  git = {
    url = "ssh://git@github.com/geeone/gitops-k8s-platform.git"

    ssh = {
      username    = "git"
      private_key = file("${path.module}/flux-id-ed25519")
    }
  }
}
