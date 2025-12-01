// Bootstrap Flux and sync from clusters/staging
resource "flux_bootstrap_git" "this" {
  embedded_manifests = true
  path               = "clusters/staging"

  depends_on = [module.eks]
}
