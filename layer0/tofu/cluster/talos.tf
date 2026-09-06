locals {
  # Sorted so bootstrap always targets the same node across plans.
  node_names = sort(keys(var.nodes))
  first_node = var.nodes[local.node_names[0]]
  node_ips   = [for name in local.node_names : var.nodes[name].ip]

  # The VIP, not any single node -- that is the point of having one.
  cluster_endpoint = "https://${var.cluster_vip}:6443"
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.node_ips
  nodes                = local.node_ips
}

resource "talos_machine_configuration_apply" "this" {
  for_each = var.nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.ip
  endpoint                    = each.value.ip

  config_patches = [
    templatefile("${path.module}/patches/common.yaml.tftpl", {
      install_disk    = var.install_disk
      installer_image = data.talos_image_factory_urls.this.urls.installer
      time_servers    = jsonencode(var.time_servers)
    }),
    templatefile("${path.module}/patches/node.yaml.tftpl", {
      hostname    = each.key
      address     = "${each.value.ip}/${var.network_prefix}"
      gateway     = var.network_gateway
      nameservers = jsonencode(var.nameservers)
      vip         = var.cluster_vip
    }),
  ]

  depends_on = [time_sleep.wait_for_maintenance]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_node.ip
  endpoint             = local.first_node.ip

  depends_on = [talos_machine_configuration_apply.this]
}

# skip_kubernetes_checks is required here: with `cni: none` the nodes stay
# NotReady until Cilium is installed by layer0/tofu/bootstrap, so the Kubernetes
# half of the health check could never pass at this stage.
data "talos_cluster_health" "this" {
  client_configuration   = talos_machine_secrets.this.client_configuration
  control_plane_nodes    = local.node_ips
  endpoints              = local.node_ips
  skip_kubernetes_checks = true

  timeouts = {
    read = "15m"
  }

  depends_on = [talos_machine_bootstrap.this]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_node.ip
  endpoint             = local.first_node.ip

  depends_on = [talos_machine_bootstrap.this]
}
