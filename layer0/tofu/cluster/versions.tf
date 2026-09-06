terraform {
  # State encryption (the `encryption` block) requires OpenTofu >= 1.7.
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.112"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.11"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }

  # The state holds the Talos PKI: cluster CA, etcd CA, the disk encryption
  # secrets and the machine join token. It is committed to this repo *encrypted*
  # so the cluster stays reproducible, instead of those secrets existing only
  # inside the running cluster (which is how the previous rebuild nearly lost
  # them).
  #
  # `enforced = true` makes OpenTofu refuse to write plaintext state at all.
  # Variables are allowed here because they resolve during `tofu init`.
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }

    state {
      method   = method.aes_gcm.main
      enforced = true
    }

    plan {
      method   = method.aes_gcm.main
      enforced = true
    }
  }
}
