# Non-secret configuration. Secrets come from the environment -- see
# layer0/tofu/.envrc.example. Do not put the API token or state passphrase here.

cluster_name  = "layer0"
talos_version = "v1.13.10"

# --- Proxmox -----------------------------------------------------------------
# proxmox_endpoint is read from PROXMOX_VE_ENDPOINT.
image_datastore_id = "local"     # must accept the "iso" content type
vm_datastore_id    = "local-zfs" # default; per-node overrides in the nodes map
network_bridge     = "vmbr0"

# --- Networking --------------------------------------------------------------
# The VIP and every node address must be static: outside the DHCP range AND
# outside the Cilium LB pool, which is 10.0.10.200-254
# (layer0/apps/cilium/ippool.yaml). DHCP hands out up to 10.0.10.199.
cluster_vip     = "10.0.10.10"
network_gateway = "10.0.10.1"
network_prefix  = 24
nameservers     = ["10.0.10.1"]
time_servers    = ["no.pool.ntp.org"]

# --- Nodes -------------------------------------------------------------------
# One control plane per Proxmox host. All three are schedulable.
# Adjust pve_node to your actual Proxmox node names.
nodes = {
  "layer0-cp-1" = {
    pve_node  = "pve-augustus"
    vm_id     = 121
    ip        = "10.0.10.11"
    cores     = 4
    memory    = 16384
    disk_size = 200
  }
  "layer0-cp-2" = {
    pve_node  = "pve-tiberius"
    vm_id     = 122
    ip        = "10.0.10.12"
    cores     = 4
    memory    = 16384
    disk_size = 200
  }
  "layer0-cp-3" = {
    pve_node  = "pve-claudius"
    vm_id     = 123
    ip        = "10.0.10.13"
    cores     = 4
    memory    = 16384
    disk_size = 200
    # NAS host -- no local-zfs here.
    vm_datastore_id = "tank"
  }
}
