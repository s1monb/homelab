# Proxmox Cluster

I have two physical nodes in my homelab, which are both running Proxmox.
The nodes are configured as a proxmox-cluster, which means that they are able
to communicate with each other and share resources.

## Getting started

Here is how you would set up a proxmox-cluster with two nodes.

### Installing Proxmox

To get started with the cluster, you need to install Proxmox on both nodes.
You can follow the [Proxmox installation guide](https://pve.proxmox.com/wiki/Installation) to do this. <!-- markdownlint-disable-line MD013 # Link length != length -->

### Creating a cluster

Then, you need to create a cluster on one of the nodes. You can do this in the
Proxmox web interface by going to `Datacenter` -> `Cluster` and clicking on
`Create Cluster`.

When doing this you will be asked to provide a name for the cluster. This name
cannot be changed later. In my case I have named the cluster `pve-zone-01` to
not confuse proxmox-cluster with kubernetes-clusters.

After creating the cluster, you will get a string called `Join-information`.
If not, it is found under `Datacenter` -> `Cluster` -> `Join Information`.
Copy this, because we will use it in the next step.

### Joining a cluster

To join the second node to the cluster, you need to go to the `Datacenter` ->
`Cluster` on the second node and click on `Join Cluster`. Paste the
`Join Information` string from the first node. Next you will be asked for a
root password, which is the password for the root user on the first node. Enter
this password and click on `Join Cluster`.

Now you should see both nodes in the proxmox web interface under Datacenter.
