# Build an image factory schematic for the extensions we want, resolve it to a
# nocloud disk image URL, and have Proxmox download it. The VMs then boot
# straight off that disk -- there is no ISO, no USB stick and no install step.

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version

  filters = {
    names = var.talos_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
      }
    }
  })
}

data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "nocloud"
  architecture  = "amd64"
}

locals {
  # pve_node -> the iso datastore to use on that host. Grouped so two Talos
  # nodes on the same Proxmox host resolve to a single download.
  image_datastore_by_host = {
    for host, choices in {
      for node in var.nodes :
      node.pve_node => coalesce(node.image_datastore_id, var.image_datastore_id)...
    } : host => choices[0]
  }
}

# One copy per Proxmox host, since a node can only clone a disk from its own
# storage unless the datastore is shared.
resource "proxmox_download_file" "talos_nocloud" {
  for_each = local.image_datastore_by_host

  node_name    = each.key
  datastore_id = each.value

  # "iso", not "import". PVE only decompresses for the iso content type --
  # `die "decompression not supported for $content" if $content ne 'iso'` -- and
  # the factory publishes no uncompressed image, so "import" is a dead end here.
  # The disk in vms.tf therefore uses `file_id` rather than `import_from`.
  content_type = "iso"

  # The factory's disk_image URL is .raw.xz, but Proxmox' download-url API only
  # knows gz/lzo/zst/bz2 -- there is no xz. The factory publishes the identical
  # image as .raw.zst, so ask for that one. (A no-op if the factory ever makes
  # zst the default.)
  url                     = replace(data.talos_image_factory_urls.this.urls.disk_image, ".raw.xz", ".raw.zst")
  decompression_algorithm = "zst"

  # iso content accepts .iso or .img (PVE's ISO_EXT_RE_0). A raw disk image
  # under a .img name is the documented way to land one on iso storage.
  #
  # The schematic id is in the name so a change of extensions downloads a new
  # image rather than silently reusing the old one.
  file_name = "talos-${var.talos_version}-${substr(talos_image_factory_schematic.this.id, 0, 12)}-nocloud-amd64.img"

  overwrite = false
}
