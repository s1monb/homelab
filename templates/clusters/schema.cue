package clusters

#node: {
	name:    string
	ip:      string
	cpu:     int | *2
	memory:  int | *4
	storage: int | *25
}

cluster_name:    string
default_gateway: string
control_plane: {
	nodes: [...#node]
}

talos_version: "blue" | "green"

worker_nodes: [...#node]

#virtual_machine: {
	_cores:      int
	_memory:     int
	_storage:    int
	_ip_address: string

	name: string

	description: "Managed by Terraform"
	tags: ["terraform"]
	node_name: "pve"
	on_boot:   true
	cpu: {
		cores: _cores
		type:  "x86-64-v2-AES"
	}
	memory: {
		dedicated: _memory * 1024
	}
	agent: {
		enabled: true
	}
	network_device: {
		bridge: "vmbr0"
	}
	disk: {
		datastore_id: "local-lvm"
		file_id:      "${var.iso_file}"
		file_format:  "raw"
		interface:    "virtio0"
		size:         _storage
	}

	operating_system: {
		type: "l26"
	}

	initialization: {
		datastore_id: "local-lvm"
		ip_config: {
			ipv4: {
				address: _ip_address + "/24"
				gateway: default_gateway
			}
			ipv6: {
				address: "dhcp"
			}
		}
	}

}
