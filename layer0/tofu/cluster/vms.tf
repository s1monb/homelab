resource "proxmox_virtual_environment_vm" "talos" {
  for_each = var.nodes

  name        = each.key
  node_name   = each.value.pve_node
  vm_id       = each.value.vm_id
  description = "Talos control plane for cluster ${var.cluster_name} - managed by OpenTofu, do not edit in the UI"
  tags        = ["talos", var.cluster_name]

  on_boot         = true
  stop_on_destroy = true # Talos does not shut down on ACPI, so destroy needs a hard stop

  # Talos has no memory hotplug, so ballooning must stay off (floating = 0).
  memory {
    dedicated = each.value.memory
    floating  = 0
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  # "VirtIO SCSI single" is known to hang the Talos bootstrap -- use plain
  # virtio-scsi. Sidero's Proxmox guide also calls for q35 + UEFI.
  scsi_hardware = "virtio-scsi-pci"
  bios          = "ovmf"
  machine       = "q35"

  operating_system {
    type = "l26"
  }

  agent {
    enabled = var.vm_agent_enabled
  }

  efi_disk {
    datastore_id      = coalesce(each.value.vm_datastore_id, var.vm_datastore_id)
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = false
  }

  disk {
    datastore_id = coalesce(each.value.vm_datastore_id, var.vm_datastore_id)
    interface    = "scsi0"
    # file_id, not import_from: bpg requires file_id for anything downloaded
    # with decompression_algorithm.
    file_id     = proxmox_download_file.talos_nocloud[each.value.pve_node].id
    size        = each.value.disk_size
    file_format = "raw"
    cache       = "writethrough"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # Proxmox writes a `cidata` drive, and Talos' nocloud platform reads
  # network-config from it. That gives each node a known address while it sits
  # in maintenance mode, which is what talos_machine_configuration_apply needs
  # to reach it. The same address is pinned again in patches/node.yaml.tftpl so
  # it survives once the machine config takes over.
  #
  # Talos will also try to read Proxmox' cloud-init user-data, fail to parse it
  # as a machine config, and stay in maintenance mode. That is expected.
  initialization {
    datastore_id = coalesce(each.value.vm_datastore_id, var.vm_datastore_id)

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.network_prefix}"
        gateway = var.network_gateway
      }
    }
  }

  boot_order = ["scsi0"]

  lifecycle {
    # The disk is only imported at create time; later image changes are rolled
    # out with `talosctl upgrade`, not by recreating the VM.
    ignore_changes = [disk[0].file_id]
  }
}

# Give Talos time to finish booting into maintenance mode before we try to talk
# to it. With the guest agent enabled the provider already waits for an IP, but
# an address appearing is not the same as the Talos API being up.
resource "time_sleep" "wait_for_maintenance" {
  depends_on      = [proxmox_virtual_environment_vm.talos]
  create_duration = var.node_boot_delay

  triggers = {
    nodes = jsonencode({ for k, v in var.nodes : k => v.ip })
  }
}
