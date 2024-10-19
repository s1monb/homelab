provider "proxmox" {
  endpoint = "https://10.1.0.100:8006/"
  insecure = true # Only needed if your proxmox server is using a self-signed certificate
}
