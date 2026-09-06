# ---------------------------------------------------------------------------
# Secrets — supplied from the environment, never from tfvars (which is committed)
# ---------------------------------------------------------------------------

variable "state_passphrase" {
  description = "Passphrase used to encrypt the OpenTofu state. Minimum 16 characters. Set via TF_VAR_state_passphrase."
  type        = string
  sensitive   = true
}

variable "proxmox_api_token" {
  description = "Proxmox API token, in the form 'user@realm!tokenid=uuid'. Prefer the PROXMOX_VE_API_TOKEN env var."
  type        = string
  sensitive   = true
  default     = null
}

# ---------------------------------------------------------------------------
# Proxmox
# ---------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint, e.g. https://10.0.10.2:8006/. Prefer the PROXMOX_VE_ENDPOINT env var."
  type        = string
  default     = null
}

variable "proxmox_ssh_username" {
  description = "SSH user on the Proxmox nodes. Required with API token auth -- there is no username to infer from a token."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_agent" {
  description = "Use the local ssh-agent for the Proxmox SSH connection. The provider ignores ~/.ssh/config."
  type        = bool
  default     = true
}

variable "proxmox_ssh_private_key" {
  description = "PEM private key for the Proxmox SSH connection. Only needed when no ssh-agent is available."
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_insecure" {
  description = "Skip TLS verification against the Proxmox API (true for a self-signed homelab cert)."
  type        = bool
  default     = true
}

variable "image_datastore_id" {
  description = "Proxmox datastore that receives the downloaded Talos disk image. Must accept the 'iso' content type."
  type        = string
  default     = "local"
}

variable "vm_datastore_id" {
  description = "Proxmox datastore for VM disks."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox bridge the Talos NICs attach to."
  type        = string
  default     = "vmbr0"
}

# ---------------------------------------------------------------------------
# Talos / Kubernetes
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Talos cluster name."
  type        = string
  default     = "layer0"
}

variable "talos_version" {
  description = <<-EOT
    Talos version to install and to generate the machine config contract against.
    Keep this within the Talos machinery version the pinned talos provider was
    built against (provider 0.11.x => Talos 1.13.x); a newer contract than the
    provider knows about will fail config generation.
  EOT
  type        = string
  default     = "v1.13.10"
}

variable "kubernetes_version" {
  description = "Kubernetes version to install. null means 'whatever this Talos version defaults to'."
  type        = string
  default     = null
}

variable "talos_extensions" {
  description = "Official Talos system extensions baked into the image factory schematic."
  type        = list(string)
  default     = ["siderolabs/qemu-guest-agent"]
}

variable "install_disk" {
  description = "Disk Talos installs to on upgrade. scsi0 on virtio-scsi shows up as /dev/sda."
  type        = string
  default     = "/dev/sda"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "cluster_vip" {
  description = <<-EOT
    Talos shared virtual IP for the control plane. The Kubernetes API endpoint
    becomes https://<vip>:6443, so losing one Proxmox host does not take the
    API server with it. Must be free and on the same L2 as the nodes -- do NOT
    put it inside the Cilium LB pool (layer0/apps/cilium/ippool.yaml).
  EOT
  type        = string
}

variable "network_gateway" {
  description = "Default gateway for the Talos nodes."
  type        = string
}

variable "network_prefix" {
  description = "Netmask prefix length for the node subnet."
  type        = number
  default     = 24
}

variable "nameservers" {
  description = "DNS servers for the Talos nodes."
  type        = list(string)
}

variable "time_servers" {
  description = "NTP servers for the Talos nodes."
  type        = list(string)
  default     = ["pool.ntp.org"]
}

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------

variable "nodes" {
  description = <<-EOT
    The Talos nodes, keyed by hostname. One per Proxmox host gives an HA control
    plane. Adding a node is: add an entry here and `tofu apply`.
  EOT
  type = map(object({
    pve_node  = string
    vm_id     = number
    ip        = string
    cores     = optional(number, 4)
    memory    = optional(number, 8192)
    disk_size = optional(number, 128)

    # Per-host storage overrides. Proxmox datastores are not necessarily
    # present on every node -- a NAS host may expose something entirely
    # different. Leave null to use the cluster-wide defaults below.
    vm_datastore_id    = optional(string)
    image_datastore_id = optional(string)
  }))

  validation {
    condition     = length(var.nodes) % 2 == 1
    error_message = "Use an odd number of control-plane nodes so etcd can form a quorum."
  }
}

variable "vm_agent_enabled" {
  description = <<-EOT
    Whether to enable the QEMU guest agent on the VMs. Requires
    siderolabs/qemu-guest-agent in talos_extensions. Set to false if `tofu apply`
    hangs waiting for the agent to report an IP address.
  EOT
  type        = bool
  default     = true
}

variable "node_boot_delay" {
  description = "How long to wait after creating the VMs before applying machine config, so Talos has reached maintenance mode."
  type        = string
  default     = "90s"
}
