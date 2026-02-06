terraform {
  required_providers {
    talos = {
      source = "siderolabs/talos"
      version = "0.10.1"
    }
  }
}

provider "talos" {}

variable "extensions" {
  type = list(string)
  default = []
}

variable "talos_version" {
  type = string
}

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = var.extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode(
    {
      customization = {
        extraKernelArgs = [
          "-talos.halt_if_installed"
        ]
        systemExtensions = {
          officialExtensions = var.extensions
        }
      }
    }
  )
}

output "schematic_id" {
  value = talos_image_factory_schematic.this.id
}
