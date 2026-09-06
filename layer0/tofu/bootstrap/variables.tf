variable "state_passphrase" {
  description = "Passphrase used to encrypt the OpenTofu state. Set via TF_VAR_state_passphrase."
  type        = string
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Kubeconfig written by layer0/tofu/cluster."
  type        = string
  default     = "../cluster/output/kubeconfig"
}

variable "cilium_version" {
  description = "Cilium chart version. Keep in sync with layer0/apps/cilium/cilium.yaml, which takes ownership after bootstrap."
  type        = string
  default     = "1.19.0"
}

variable "argocd_version" {
  description = "argo-cd chart version. Keep in sync with layer0/apps/argocd/argocd.yaml, which takes ownership after bootstrap."
  type        = string
  default     = "9.4.0"
}

variable "onepassword_credentials_file" {
  description = <<-EOT
    Path to the *decoded* 1password-credentials.json for the Connect server.
    This is the file that closes the bootstrap gap: without it external-secrets
    has no way into the vault and every ExternalSecret in the cluster fails.
    A verified copy is in the backup at
    ~/homelab-backup-2026-09-05/secrets/00-BOOTSTRAP-CRITICAL/.
  EOT
  type        = string
}

variable "onepassword_connect_token" {
  description = "1Password Connect API token (JWT) for the ClusterSecretStore. Set via TF_VAR_onepassword_connect_token."
  type        = string
  sensitive   = true
}

variable "root_application_manifest" {
  description = "Root ArgoCD app-of-apps manifest to apply once ArgoCD is up."
  type        = string
  default     = "../../bootstrap-manifests/argocd/apps-of-apps.yaml"
}
