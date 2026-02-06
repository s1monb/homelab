#! /usr/bin/env bash

# Dependencies:
# fzf (required for interactive version selection)
# tofu (https://github.com/hashicorp/terraform-tofu)
# jq (for JSON parsing)
# docker (required for fetching compatible extensions using crane image)

# Select a Talos version interactively using fzf
# Returns the selected version tag (e.g., "v1.7.0") or exits with error
select_talos_version() {
    local api_url="https://api.github.com/repos/siderolabs/talos/releases"
    local selected_version
    
    # Fetch versions and pipe to fzf for selection (latest first)
    selected_version=$(curl -s "$api_url" | jq -r '.[].tag_name' | sort -Vr | \
        fzf --prompt="Select Talos version: " --height=40% --reverse)
    
    if [[ -z "$selected_version" ]]; then
        echo "No version selected" >&2
        return 1
    fi
    
    echo "$selected_version"
}

# Get available Talos extensions for a specific version using crane via Docker
get_available_extensions() {
    local version="$1"
    local extensions
    
    if ! command -v docker &> /dev/null; then
        echo "Error: docker is required but not installed" >&2
        return 1
    fi
    
    local image="ghcr.io/siderolabs/extensions:${version}"
    
    # Export and extract image-digests using crane via Docker, then parse extension names
    extensions=$(docker run --rm gcr.io/go-containerregistry/crane export "$image" 2>/dev/null | \
        tar x -O image-digests 2>/dev/null | \
        grep -oE 'siderolabs/[^:]+' | sort -u)
    
    if [[ -z "$extensions" ]]; then
        echo "Error: Failed to fetch extensions for version $version" >&2
        return 1
    fi
    
    echo "$extensions"
}

# Select Talos extensions interactively using fzf (multi-select with toggle)
# Returns selected extensions as a JSON array string for Terraform
# Parameter: talos_version (e.g., "v1.7.0")
select_talos_extensions() {
    local talos_version="$1"
    
    if ! command -v fzf &> /dev/null; then
        echo "Error: fzf is required but not installed" >&2
        return 1
    fi
    
    # Get available extensions for the selected version
    local extensions
    extensions=$(get_available_extensions "$talos_version")
    
    # Use fzf with multi-select (--multi) to allow toggling selections
    # TAB to toggle, ENTER to confirm
    local selected
    selected=$(echo "$extensions" | \
        fzf --multi \
            --prompt="Select extensions (TAB to toggle, ENTER to confirm): " \
            --height=40% \
            --reverse)
    
    if [[ -z "$selected" ]]; then
        # Return empty JSON array if nothing selected
        echo "[]"
        return 0
    fi
    
    # Convert selected extensions to JSON array format for Terraform
    local json_array
    json_array=$(echo "$selected" | jq -R -s 'split("\n") | map(select(length > 0))')
    echo "$json_array"
}

# Get the Talos ISO URL from schematic_id and version
# Format: https://factory.talos.dev/image/{schematic_id}/{version}/metal-amd64.iso
get_talos_iso_url() {
    local schematic_id="$1"
    local version="$2"
    
    if [[ -z "$schematic_id" ]] || [[ -z "$version" ]]; then
        echo "Error: schematic_id and version are required" >&2
        return 1
    fi
    
    echo "https://factory.talos.dev/image/${schematic_id}/${version}/metal-amd64.iso"
}

TALOS_VERSION=$(select_talos_version)

# Select extensions (optional - can be empty array)
# Pass version to get compatible extensions for that version
TALOS_EXTENSIONS=$(select_talos_extensions "$TALOS_VERSION")

tofu init > /dev/null

# Apply with version and extensions (extensions can be empty array)
tofu apply -var "talos_version=$TALOS_VERSION" -var "extensions=$TALOS_EXTENSIONS" -auto-approve > /dev/null

# Get schematic_id from Terraform output
SCHEMATIC_ID=$(tofu output -raw schematic_id)

# Get the ISO URL
TALOS_ISO_URL=$(get_talos_iso_url "$SCHEMATIC_ID" "$TALOS_VERSION")

rm -rf .terraform* terraform.tfstate*

echo "Downloading Talos ISO..."
wget -q -O "talos-${TALOS_VERSION}.iso" "$TALOS_ISO_URL"

# Select a USB device interactively using fzf and write ISO to it
# Returns the selected device path (e.g., "/dev/sdb")
select_usb_device() {
    local selected_device
    # List block devices, filter for removable disks, format as "device (size model)"
    selected_device=$(lsblk -d -n -o NAME,SIZE,MODEL,TYPE | \
        awk '/disk/ && ($3 != "" || $4 == "disk") {print "/dev/" $1 " (" $2 " " $3 ")"}' | \
        fzf --prompt="Select USB device: " --height=40% --reverse | \
        awk '{print $1}')
    
    if [[ -z "$selected_device" ]]; then
        echo "No device selected" >&2
        return 1
    fi
    
    echo "$selected_device"
}

# Write ISO to USB device
write_iso_to_usb() {
    local iso_file="$1"
    local usb_device="$2"

    if [[ ! -f "$iso_file" ]]; then
        echo "Error: ISO file not found: $iso_file" >&2
        return 1
    fi
    
    if [[ ! -b "$usb_device" ]]; then
        echo "Error: Not a block device: $usb_device" >&2
        return 1
    fi
    
    # Warn about data loss
    echo "WARNING: This will erase all data on $usb_device" >&2
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Aborted" >&2
        return 1
    fi
    
    # Unmount any mounted partitions on the device
    if mount | grep -q "^${usb_device}"; then
        echo "Unmounting partitions on $usb_device..." >&2
        sudo umount "${usb_device}"* 2>/dev/null || true
    fi
    
    # Write ISO to USB device
    echo "Writing $iso_file to $usb_device (this may take a while)..." >&2
    if command -v pv &> /dev/null; then
        # Use pv for progress bar if available
        sudo dd if="$iso_file" of="$usb_device" bs=4M status=progress oflag=sync
    else
        sudo dd if="$iso_file" of="$usb_device" bs=4M status=progress oflag=sync
    fi
    
    if [[ $? -eq 0 ]]; then
        echo "Successfully wrote ISO to $usb_device" >&2
        sync
    else
        echo "Error: Failed to write ISO to $usb_device" >&2
        return 1
    fi
}

# Safely unmount and prepare USB device for removal
safe_unmount_usb() {
    local usb_device="$1"
    
    if [[ -z "$usb_device" ]]; then
        echo "Error: USB device path is required" >&2
        return 1
    fi
    
    # Get the device name without /dev/ prefix for udisksctl
    local device_name="${usb_device#/dev/}"
    
    # Unmount any mounted partitions
    echo "Unmounting partitions on $usb_device..." >&2
    sudo umount "${usb_device}"* 2>/dev/null || true
    
    # Sync to ensure all data is written
    sync
    
    # Try to power off the device using udisksctl (preferred method)
    if command -v udisksctl &> /dev/null; then
        echo "Safely ejecting $usb_device..." >&2
        udisksctl power-off -b "$usb_device" 2>/dev/null || true
    # Fallback to eject command
    elif command -v eject &> /dev/null; then
        echo "Safely ejecting $usb_device..." >&2
        sudo eject "$usb_device" 2>/dev/null || true
    else
        echo "Note: udisksctl or eject not found. Device may still be in use." >&2
        echo "You can manually unmount with: sudo umount ${usb_device}*" >&2
    fi
    
    echo "USB device $usb_device is now safe to unplug" >&2
}

# Select USB device and write ISO
USB_DEVICE=$(select_usb_device)
if [[ $? -eq 0 ]]; then
    write_iso_to_usb "talos-${TALOS_VERSION}.iso" "$USB_DEVICE"
    if [[ $? -eq 0 ]]; then
        safe_unmount_usb "$USB_DEVICE"
    fi
fi

rm -rf "talos-${TALOS_VERSION}.iso"
