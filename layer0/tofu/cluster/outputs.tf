# Written to disk so direnv can point TALOSCONFIG/KUBECONFIG at them.
# output/ is gitignored -- the authoritative copy is the encrypted state.

resource "local_sensitive_file" "talosconfig" {
  content              = data.talos_client_configuration.this.talos_config
  filename             = "${path.module}/output/talosconfig"
  file_permission      = "0600"
  directory_permission = "0700"
}

resource "local_sensitive_file" "kubeconfig" {
  content              = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename             = "${path.module}/output/kubeconfig"
  file_permission      = "0600"
  directory_permission = "0700"
}

output "talosconfig" {
  description = "Talos client configuration."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes client configuration."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to the written kubeconfig, consumed by layer0/tofu/bootstrap."
  value       = abspath(local_sensitive_file.kubeconfig.filename)
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint (the shared control-plane VIP)."
  value       = local.cluster_endpoint
}

output "node_ips" {
  description = "Talos node addresses."
  value       = local.node_ips
}

output "talos_image_schematic_id" {
  description = "Image factory schematic id, needed for `talosctl upgrade`."
  value       = talos_image_factory_schematic.this.id
}

output "talos_installer_image" {
  description = "Factory installer image for this schematic and Talos version."
  value       = data.talos_image_factory_urls.this.urls.installer
}
