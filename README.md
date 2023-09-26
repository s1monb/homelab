# homelab

## Setup

### Setup the nodes

When going through the guide bellow, you should:

1. Skip the last step.
2. Run this `sudo kubeadm init --control-plane-endpoint=k8s-master` when you are initializing the cluster.

Follow [this guide](https://www.linuxtechi.com/install-kubernetes-cluster-on-debian/).

### Setup Cilium (CNI)

Install it on the cluster:

```bash
kubectl kustomize --enable-helm infrastructure/cilium | kubectl apply -f -
```

Test the cilium install:

```bash
cilium status

# AND TEST THE CONNECTION

cilium connectivity test
```

### LoadBalancer with cilium

With Cilium version `>=14`, IP-assignment and announcement is enabled easily by adding an ip-pool to the cluster and setting the `l2announcement.enabled=true`.

LoadBalancing is enabled in the `values.yaml`-file.

You can request spesific ips (like `192.168.0.200`) in the pool by annotation `LoadBalancer`s with `"io.cilium/lb-ipam-ips": "192.168.0.200"`.

## References

- [Link to cilium install guide](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)
