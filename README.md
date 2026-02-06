# Homelab

## Layer 0

### Talos

#### Install

Create a bootable usb with talos image, containing wanted extentions.

```bash
cd layer0/talos-to-usb

# Select version, extentions, and usb
./talos-to-usb
```

Then boot the first machine with this usb.

#### Config

Because of my cluster-size, I do not seperate between controlplane-nodes and worker-nodes.

See the patches for all of the nodes in the `layer0/talos-cfg/`-folder.

Tips: see the `.envrc`-file. Use direnv to load the env-variables

Generate the new base config and apply the patches:

```bash
cd layer0/talos-cfg

export INIT_NODE_IP=<ip-to-init-node>
# make sure install-disk is correct in disk-selector.yaml
talosctl get disks --nodes $INIT_NODE_IP --insecure

talosctl gen config layer0 https://$INIT_NODE_IP:6443 --force --output-dir . --config-patch @patch.yaml

talosctl config endpoint $INIT_NODE_IP
talosctl config nodes $INIT_NODE_IP
```

You should now be have the `talosconfig`, `controlplane.yaml` and `worker.yaml`-files.

#### Bootstrap cluster

Apply config to the first node (init node), then bootstrap Kubernetes:

```bash
talosctl apply-config --nodes $INIT_NODE_IP --file controlplane.yaml --insecure
# After the node is ready (talosctl health):
talosctl bootstrap --nodes $INIT_NODE_IP
```

Wait for the cluster to be ready (`talosctl health` or `kubectl get nodes`).

#### Install bootstrap-packages

For now we only need to install cilium and argo-cd. The rest of the config is handled through gitops.

```bash
cd layer0/bootstrap-manifests

./bootstrap.sh
```

This will install argocd, and point an application towards the `layer0/apps-of-apps`-folder in this public repo.

Change the `layer0/bootstrap-manifests/argocd/apps-of-apps.yaml`-file to fit your needs.

#### Add nodes

Adding a new node is as easy as booting it up on the iso and running:

```bash
talosctl apply-config --nodes <NEW_NODE_IP> --file controlplane.yaml --insecure
```

#### Update Talos image (version, extentions etc.)

TODO

#### Update config

Edit the config (or patches) in `layer0/talos-cfg/`, then apply to the relevant nodes without reinstalling:

```bash
talosctl apply-config --nodes <NODE_IP> --file controlplane.yaml --mode no-reboot
```

### Todo

- Figure out how to install and use multus CNI aside cilium
- Figure out how to do hubble good and debug network issues
- Figure out how to install and use kubevirt
- Figure out how to install and use longhorn
- Figure out how to install and use openbao
