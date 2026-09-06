# Chart versions must match the ArgoCD Applications that adopt these releases:
#   cilium  -> layer0/apps/cilium/cilium.yaml
#   argo-cd -> layer0/apps/argocd/argocd.yaml
cilium_version = "1.19.0"
argocd_version = "9.4.0"

# The decoded credentials file, from the verified backup.
onepassword_credentials_file = "~/homelab-backup-2026-09-05/secrets/00-BOOTSTRAP-CRITICAL/1password-credentials.json"

# onepassword_connect_token comes from TF_VAR_onepassword_connect_token.
