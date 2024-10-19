locals {
  talos = {
    version = {
      green = "v1.8.0"
      blue  = "v1.7.4"
    }
  }

}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image_green" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"

  file_name               = "talos-${local.talos.version.green}-nocloud-amd64.img"
  url                     = "https://factory.talos.dev/image/787b79bb847a07ebb9ae37396d015617266b1cef861107eaec85968ad7b40618/${local.talos.version.green}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
  overwrite_unmanaged     = true
}


resource "proxmox_virtual_environment_download_file" "talos_nocloud_image_blue" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"

  file_name               = "talos-${local.talos.version.blue}-nocloud-amd64.img"
  url                     = "https://factory.talos.dev/image/787b79bb847a07ebb9ae37396d015617266b1cef861107eaec85968ad7b40618/${local.talos.version.blue}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
  overwrite_unmanaged     = true
}
