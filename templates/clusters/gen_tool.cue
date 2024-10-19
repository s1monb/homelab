package clusters

import (
	"tool/file"
	"list"
	"encoding/json"
	"encoding/yaml"
)

command: gen: {
	_cluster_name: cluster_name
	_worker_nodes: worker_nodes
	mkdir: file.Mkdir & {
		path: "../../infra/terraform/generated/clusters/\(cluster_name)/"
	}
	providers: file.Create & {
		$dep:     mkdir.$done
		filename: "../../infra/terraform/generated/clusters/\(cluster_name)/required-providers.tf.json"
		contents: json.Marshal({
			terraform: {
				required_providers: {
					proxmox: {
						source:  "bpg/proxmox"
						version: "0.65.0"
					}
					talos: {
						source:  "siderolabs/talos"
						version: "0.6.0"
					}
				}
			}
			variable: {
				iso_file: {
					type: "string"
				}
			}
		})
	}
	workerNodes: file.Create & {
		$dep:     mkdir.$done
		filename: "../../infra/terraform/generated/clusters/\(cluster_name)/workernode-vms.tf.json"
		contents: json.Marshal({
			resource: {
				proxmox_virtual_environment_vm: {
					for node in worker_nodes {
						"\(cluster_name)_\(node.name)": #virtual_machine & {
							name:        cluster_name + "-" + node.name
							_cores:      node.cpu
							_memory:     node.memory
							_storage:    node.storage
							_ip_address: node.ip
						}
					}
				}
				talos_machine_configuration_apply: {
					for _node in worker_nodes {
						"\(cluster_name)_\(_node.name)_config_apply": {
							depends_on: ["proxmox_virtual_environment_vm.\(cluster_name)_\(_node.name)"]
							client_configuration:        "${talos_machine_secrets.\(cluster_name)_machine_secrets.client_configuration}"
							machine_configuration_input: "${data.talos_machine_configuration.\(cluster_name)_machineconfig_worker.machine_configuration}"
							node:                        _node.ip
						}
					}
				}
			}
		})
	}

	controlPlaneNodes: file.Create & {
		$dep:     mkdir.$done
		filename: "../../infra/terraform/generated/clusters/\(cluster_name)/controlplane-vms.tf.json"
		contents: json.Marshal({
			resource: {
				proxmox_virtual_environment_vm: {
					for node in control_plane.nodes {
						"\(cluster_name)_\(node.name)": #virtual_machine & {
							name:        cluster_name + "-" + node.name
							_cores:      node.cpu
							_memory:     node.memory
							_storage:    node.storage
							_ip_address: node.ip
						}
					}
				}
				talos_machine_configuration_apply: {
					for _node in control_plane.nodes {
						"\(cluster_name)_\(_node.name)_config_apply": {
							depends_on: ["proxmox_virtual_environment_vm.\(cluster_name)_\(_node.name)"]
							client_configuration:        "${talos_machine_secrets.\(cluster_name)_machine_secrets.client_configuration}"
							machine_configuration_input: "${data.talos_machine_configuration.\(cluster_name)_machineconfig_cp.machine_configuration}"
							node:                        _node.ip
						}
					}
				}
			}
		})
	}

	createCluster: file.Create & {
		$dep:     mkdir.$done
		filename: "../../infra/terraform/generated/clusters/\(cluster_name)/cluster.tf.json"
		contents: json.Marshal({
			resource: {
				talos_machine_secrets: {
					"\(cluster_name)_machine_secrets": {}
				}
				talos_machine_bootstrap: {
					"\(cluster_name)_bootstrap": {
						depends_on: [for node in control_plane.nodes {"talos_machine_configuration_apply.\(cluster_name)_\(node.name)_config_apply"}]
						client_configuration: "${talos_machine_secrets.\(cluster_name)_machine_secrets.client_configuration}"
						node:                 control_plane.nodes[0].ip
					}
				}
				talos_cluster_kubeconfig: {
					"\(cluster_name)_kubeconfig": {
						depends_on: ["talos_machine_bootstrap.\(cluster_name)_bootstrap"]
						client_configuration: "${data.talos_client_configuration.\(cluster_name)_talosconfig.client_configuration}"
						node:                 control_plane.nodes[0].ip
					}
				}
			}
			data: {
				talos_client_configuration: {
					"\(cluster_name)_talosconfig": {
						cluster_name:         _cluster_name
						client_configuration: "${talos_machine_secrets.\(cluster_name)_machine_secrets.client_configuration}"
						endpoints: [control_plane.nodes[0].ip]
					}
				}
				talos_machine_configuration: {
					"\(cluster_name)_machineconfig_cp": {
						cluster_name:     _cluster_name
						cluster_endpoint: "https://\(control_plane.nodes[0].ip):6443"
						machine_type:     "controlplane"
						machine_secrets:  "${talos_machine_secrets.\(cluster_name)_machine_secrets.machine_secrets}"
            config_patches: ["${templatefile(\"${path.module}/talos-config.yaml.tftpl\", {})}"]
					}
					"\(cluster_name)_machineconfig_worker": {
						cluster_name:     _cluster_name
						cluster_endpoint: "https://\(control_plane.nodes[0].ip):6443"
						machine_type:     "worker"
						machine_secrets:  "${talos_machine_secrets.\(cluster_name)_machine_secrets.machine_secrets}"
					}
				}
				talos_cluster_health: {
					"\(cluster_name)_health": {
						depends_on: [
							for node in list.Concat([control_plane.nodes, _worker_nodes]) {
								"talos_machine_configuration_apply.\(cluster_name)_\(node.name)_config_apply"
							},
						]
						client_configuration: "${data.talos_client_configuration.\(cluster_name)_talosconfig.client_configuration}"
						control_plane_nodes: [for node in control_plane.nodes {"\(node.ip)"}]
						worker_nodes: [for node in _worker_nodes {"\(node.ip)"}]
						skip_kubernetes_checks: true
						endpoints:              "${data.talos_client_configuration.\(cluster_name)_talosconfig.endpoints}"
					}
				}
			}
			output: {
				"\(cluster_name)_kubeconfig": {
					value:     "${talos_cluster_kubeconfig.\(cluster_name)_kubeconfig.kubeconfig_raw}"
					sensitive: "true"
				}
			}
		})
	}
	createTalosConfig: file.Create & {
		$dep:     mkdir.$done
		filename: "../../infra/terraform/generated/clusters/\(cluster_name)/talos-config.yaml.tftpl"
		contents: yaml.Marshal({
			cluster: {
				allowSchedulingOnControlPlanes: true
				network:
					cni:
						name: "none"
				proxy:
					disabled: true
			}
		})
}
createClusterModuleImporter: file.Create & {
	$dep:     createCluster.$done
	filename: "../../infra/terraform/generated.cluster-\(cluster_name).tf.json"
	contents: json.Marshal({
		module: "cluster-\(cluster_name)": {
			source: "./generated/clusters/\(cluster_name)"

			iso_file: "${proxmox_virtual_environment_download_file.talos_nocloud_image_\(talos_version).id}"
		}
		output: {
			"\(cluster_name)_kubeconfig": {
				value:     "${module.cluster-\(cluster_name).\(cluster_name)_kubeconfig}"
				sensitive: "true"
			}
		}
	})
}
}
