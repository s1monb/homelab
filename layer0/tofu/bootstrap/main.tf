# Stage 2: everything between "etcd is up" and "ArgoCD owns the cluster".
#
# Both Helm releases here are bootstrap-only. Once the root app-of-apps syncs,
# ArgoCD's own Applications (layer0/apps/cilium, layer0/apps/argocd) adopt the
# `cilium` and `argo-cd` releases and become the source of truth -- hence
# `ignore_changes = all`, so Tofu does not fight ArgoCD on later applies.
# Bump the chart versions in *both* places, or ArgoCD will roll one back.

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"

  values = [file("${path.module}/../../bootstrap-manifests/cilium/values.yaml")]

  # wait = false is deliberate. The chart creates a `cilium-ingress`
  # LoadBalancer Service, and Helm's wait blocks until every LoadBalancer gets
  # an external IP. That IP comes from the CiliumLoadBalancerIPPool in
  # layer0/apps/cilium/ippool.yaml, which ArgoCD delivers -- and ArgoCD is
  # installed further down this same file. Waiting here deadlocks: the release
  # sits in `pending-install` forever with every pod healthy.
  #
  # terraform_data.wait_for_nodes below is the real readiness gate.
  wait    = false
  timeout = 900

  lifecycle {
    ignore_changes = all
  }
}

# With cni: none the nodes are NotReady until Cilium lands. Nothing else can be
# scheduled before this passes.
#
# This checks what actually matters -- the agent rolled out and the kubelets
# went Ready -- rather than Helm's blanket wait, which also demands a
# LoadBalancer IP that cannot exist yet.
resource "terraform_data" "wait_for_nodes" {
  depends_on = [helm_release.cilium]

  triggers_replace = [helm_release.cilium.id]

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail
      kubectl --kubeconfig '${var.kubeconfig_path}' -n kube-system rollout status daemonset/cilium --timeout=10m
      kubectl --kubeconfig '${var.kubeconfig_path}' -n kube-system rollout status deployment/cilium-operator --timeout=10m
      kubectl --kubeconfig '${var.kubeconfig_path}' wait --for=condition=Ready nodes --all --timeout=10m
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# ---------------------------------------------------------------------------
# The bootstrap gap
#
# bootstrap.sh installed ArgoCD, ArgoCD installed external-secrets and
# onepassword-connect -- and nothing ever created the two secrets they both
# depend on. They existed only inside the running cluster, so a rebuild synced
# no secrets at all. Creating them here, before ArgoCD starts, closes that.
# ---------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }

  lifecycle {
    # ArgoCD adds its own tracking labels once it adopts the namespace.
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

# Note the double encoding: the Connect chart expects the *base64 of the
# credentials file* as the secret value, and the Kubernetes provider base64s
# `data` again on the way in. So base64encode() here is correct, not redundant.
resource "kubernetes_secret_v1" "onepassword_connect_credentials" {
  metadata {
    name      = "onepassword-connect-credentials"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }

  data = {
    "1password-credentials.json" = base64encode(file(pathexpand(var.onepassword_credentials_file)))
  }

  type = "Opaque"
}

# Referenced by layer0/apps/external-secrets/clustersecretstore.yaml.
resource "kubernetes_secret_v1" "onepassword_connect_token" {
  metadata {
    name      = "onepassword-connect-token"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }

  data = {
    token = var.onepassword_connect_token
  }

  type = "Opaque"
}

# ---------------------------------------------------------------------------
# ArgoCD, then hand over
# ---------------------------------------------------------------------------

resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = "argocd"
  create_namespace = true

  wait    = true
  timeout = 900

  depends_on = [terraform_data.wait_for_nodes]

  lifecycle {
    ignore_changes = all
  }
}

# Applied with kubectl rather than kubernetes_manifest: the Application CRD is
# installed by the Helm release above, and kubernetes_manifest needs the CRD to
# already exist at *plan* time.
resource "terraform_data" "root_application" {
  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.onepassword_connect_credentials,
    kubernetes_secret_v1.onepassword_connect_token,
  ]

  triggers_replace = [
    filesha256("${path.module}/${var.root_application_manifest}"),
    helm_release.argocd.id,
  ]

  provisioner "local-exec" {
    command     = "kubectl --kubeconfig '${var.kubeconfig_path}' apply -f '${path.module}/${var.root_application_manifest}'"
    interpreter = ["/bin/bash", "-c"]
  }
}
