# Configured from the kubeconfig that layer0/tofu/cluster writes to disk. This
# is a separate root module for exactly that reason: a provider cannot be
# configured from a resource created in the same apply.

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}
