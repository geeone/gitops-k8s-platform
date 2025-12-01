// Bootstrap Flux and sync from clusters/staging
resource "flux_bootstrap_git" "this" {
  embedded_manifests = true
  components_extra   = ["image-reflector-controller", "image-automation-controller"]
  path               = "clusters/staging"

  depends_on = [module.eks]
}
