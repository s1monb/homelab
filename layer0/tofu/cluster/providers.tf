provider "proxmox" {
  # Set PROXMOX_VE_ENDPOINT / PROXMOX_VE_API_TOKEN in the environment
  # (see layer0/tofu/.envrc.example) rather than putting them in tfvars.
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  # Required. Attaching a disk from an image downloaded with
  # `decompression_algorithm` ("creating custom disk") is done over SSH, not the
  # API -- only `import_from` is API-only, and we cannot use it because the
  # Talos factory ships nothing uncompressed.
  #
  # `username` must be explicit: with API token auth there is no username to
  # infer. The provider also ignores ~/.ssh/config, so the key has to come from
  # ssh-agent or var.proxmox_ssh_private_key.
  ssh {
    agent       = var.proxmox_ssh_agent
    username    = var.proxmox_ssh_username
    private_key = var.proxmox_ssh_private_key
  }
}

provider "talos" {}
