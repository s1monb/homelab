# Homelab

`layer0` is a 3-node Talos Kubernetes cluster running as VMs on a 3-node Proxmox
cluster, one control plane per Proxmox host. Everything from "empty Proxmox" to
"ArgoCD syncing" is OpenTofu — there is no `talosctl gen config` / `talosctl
bootstrap` step to run by hand.

```
layer0/
├── tofu/
│   ├── cluster/            # stage 1 — Proxmox VMs + Talos
│   └── bootstrap/          # stage 2 — Cilium, ArgoCD, 1Password Connect secrets
├── bootstrap-manifests/    # the manual equivalent of stage 2, kept as a fallback
├── apps-of-apps/           # ArgoCD root app points here
└── apps/                   # per-app manifests
```

## Layer 0

### Prerequisites

```bash
brew install opentofu kubectl talosctl direnv 1password-cli
```

- A Proxmox API token — see [Proxmox credentials](#proxmox-credentials) below.
- A datastore that accepts the `iso` content type for the Talos image (`local`
  by default, where it is already enabled) and one for VM disks. Datastores are
  per-host: a node whose storage differs from the rest takes a
  `vm_datastore_id` / `image_datastore_id` override in its `nodes` entry.
  The image is a raw disk image stored under a `.img` name: Proxmox only
  decompresses for `iso` content, and the factory publishes nothing
  uncompressed, so the newer `import` content type cannot be used here.
- A free IP for the control-plane VIP, plus one per node. Keep them out of the
  Cilium load balancer pool (`10.0.10.150-200`, see
  `layer0/apps/cilium/ippool.yaml`).

### Proxmox credentials

Run these once, in a root shell on any node of the Proxmox cluster. Permissions
are cluster-wide, so one token works for all three hosts.

```sh
pveum user add tofu@pve

# PVE 9. On PVE 8 add VM.Monitor as well -- it was removed in 9.0, where the
# VM.GuestAgent.* privileges took over.
pveum role add Tofu -privs "\
Datastore.Audit,Datastore.AllocateSpace,Datastore.AllocateTemplate,\
Sys.Audit,Sys.Modify,SDN.Use,\
VM.Allocate,VM.Audit,VM.PowerMgmt,VM.GuestAgent.Audit,\
VM.Config.CPU,VM.Config.Memory,VM.Config.Disk,VM.Config.Network,\
VM.Config.Options,VM.Config.HWType,VM.Config.CDROM,VM.Config.Cloudinit"

pveum aclmod / -user tofu@pve -role Tofu

# --privsep=0 makes the token inherit the user's permissions. Without it the
# token starts with none and needs its own ACL.
pveum user token add tofu@pve tofu --privsep=0
```

The last command prints the secret **once**. Put it in 1Password and build the
token string as `user@realm!tokenid=secret` — with the commands above that is
`tofu@pve!tofu=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`. That whole string is
`PROXMOX_VE_API_TOKEN`; the bare UUID on its own will not authenticate.

Proxmox validates the entire triple, so a wrong `tokenid` fails exactly like a
wrong secret: **HTTP 401 `Authentication failed!` on every endpoint**, including
`/api2/json/version`. A 403 `Permission check failed` means the opposite — auth
worked and a privilege is missing. Check what you actually issued with:

```sh
pveum user token list tofu@pve
```

Quote the value with single quotes when testing it in an interactive shell —
`!` inside double quotes triggers history expansion and will mangle it.

Why each group is there:

| Privileges | Needed for |
|---|---|
| `Datastore.AllocateTemplate`, `Sys.Audit`, `Sys.Modify` | `proxmox_download_file` — the Talos image download |
| `Datastore.AllocateSpace`, `Datastore.Audit` | VM disks and the EFI disk |
| `SDN.Use` | attaching the NIC to `vmbr0` (PVE 8.2+) |
| `VM.Allocate`, `VM.Config.*` | creating and configuring the VMs |
| `VM.Config.Cloudinit`, `VM.Config.CDROM` | the cloud-init drive that carries the static IP |
| `VM.PowerMgmt` | `on_boot` and `stop_on_destroy` |
| `VM.GuestAgent.Audit` | reading the guest agent's IP during create |

This is least-privilege for what the config actually does, not a copy of the
provider's example role. If an apply dies on `HTTP 403 Permission check failed`,
the message names the missing privilege — add it with `pveum role modify Tofu`.
`pveum role add` validates the whole list at once and names the first bad entry,
so a rejected privilege surfaces immediately; `pveum role list` shows what your
PVE version accepts.

If the Proxmox cert is self-signed, keep `PROXMOX_VE_INSECURE=true` in
`layer0/tofu/.envrc`.

### SSH access to the Proxmox nodes

Also required, on top of the API token. Attaching the Talos image to a VM
("creating custom disk") is done over SSH rather than the API. Only the
`import_from` path is pure API, and it cannot be used here because it demands an
uncompressed image and the Talos factory publishes none.

Copy a key to **every** node — the provider connects to whichever host it is
building on:

```sh
for h in 10.0.10.102 10.0.10.59 10.0.10.72; do ssh-copy-id root@$h; done
ssh-add            # the key must be in the agent
ssh-add -L         # verify it is listed
```

Two provider quirks worth knowing:

- It **ignores `~/.ssh/config`**, so a `Host`/`IdentityFile` entry there has no
  effect. The key comes from `ssh-agent`, or set `proxmox_ssh_private_key`.
- `username` must be explicit — with API token auth there is no username to
  infer, which is why the failure reads `unable to authenticate user ""`. It
  defaults to `root` via `proxmox_ssh_username`.

A non-root SSH user works too, but needs passwordless `sudo` on every node.

### Configure

```bash
cp layer0/tofu/.envrc.example layer0/tofu/.envrc
# edit the 1Password item references, then:
direnv allow layer0/tofu
```

`layer0/tofu/.envrc` supplies the state passphrase and the Proxmox token. It is
gitignored and nested, so `op read` only runs when you cd into the infra tree.

Node addresses, sizes and Proxmox host names live in
`layer0/tofu/cluster/terraform.tfvars`.

### Stage 1 — cluster

```bash
cd layer0/tofu/cluster
tofu init
tofu apply
```

This resolves a Talos image factory schematic for the extensions we want, has
each Proxmox host download the matching `nocloud` disk image, creates the VMs
from it, then generates the machine secrets, applies the config, bootstraps etcd
and writes `output/talosconfig` and `output/kubeconfig`. No ISO, no USB stick, no
install step — the VMs boot straight off the factory image.

The nodes will be `NotReady` at this point. That is correct: `cni: none` means
nothing schedules until Cilium arrives in stage 2.

```bash
direnv reload
talosctl health
```

The Kubernetes half of that health check fails until stage 2 — expected.

### Stage 2 — bootstrap

```bash
cd layer0/tofu/bootstrap
tofu init
tofu apply
```

Installs Cilium, waits for the nodes to go `Ready`, **creates the 1Password
Connect credentials and token**, installs ArgoCD, and applies the root
app-of-apps — after which ArgoCD owns the cluster.

That third step is the one that used to be missing. `bootstrap.sh` installed
ArgoCD, ArgoCD installed external-secrets and onepassword-connect, and nothing
ever created the two secrets they both depend on; they existed only inside the
running cluster, so a rebuild synced no secrets at all. Verify it worked:

```bash
kubectl get externalsecrets -A
```

Both Helm releases here are bootstrap-only. ArgoCD's own Applications
(`layer0/apps/cilium`, `layer0/apps/argocd`) adopt the `cilium` and `argo-cd`
releases immediately afterwards, so Tofu is set to ignore later drift on them.
When bumping either chart, bump it in **both** places or ArgoCD will roll the
other one back.

### State

The Tofu state holds the Talos PKI — cluster CA, etcd CA, disk encryption
secrets, machine join token. It is committed to this repo, encrypted with
AES-GCM via a PBKDF2 passphrase from 1Password, with `enforced = true` so
OpenTofu refuses to write plaintext.

**Losing the passphrase means losing the state.** It belongs in 1Password and
nowhere else.

### Add a node

Add an entry to `nodes` in `layer0/tofu/cluster/terraform.tfvars` and apply.
Keep the count odd so etcd can hold a quorum.

```bash
cd layer0/tofu/cluster && tofu apply
```

### Change machine config

Edit `layer0/tofu/cluster/patches/common.yaml.tftpl` (cluster-wide) or
`node.yaml.tftpl` (per-node identity and networking), then apply. The provider
works out whether a reboot is needed.

Address and VIP live in the same patch on purpose: Talos replaces the
`interfaces` list wholesale rather than merging it, so splitting them across two
patches silently drops one.

### Upgrade Talos

Bump `talos_version` in `terraform.tfvars` and apply — that updates the
`machine.install.image` in the config to a new factory installer. Then roll the
nodes:

```bash
talosctl upgrade --nodes <NODE_IP> --image "$(tofu output -raw talos_installer_image)"
```

Keep `talos_version` within the Talos machinery release the pinned provider was
built against (provider `0.11.x` → Talos `1.13.x`); a newer config contract than
the provider knows about fails config generation.

### Adding system extensions

Add to `talos_extensions` in `terraform.tfvars` and apply. The schematic id
changes, so a fresh image is downloaded and the installer image is updated;
existing nodes still need `talosctl upgrade` as above.

## Todo

- Figure out how to install and use multus CNI aside cilium
- Figure out how to do hubble good and debug network issues
- Figure out how to install and use kubevirt
- Figure out how to install and use longhorn
- Figure out how to install and use openbao
- Figure out how to install and use grafana and the rest of the stack
- Figure out how to install and use clusterAPI with kubevirt
