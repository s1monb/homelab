# Homelab

> *Work in progress* ⚠️

- [x] Setup a cluster with 3 nodes
- [x] Add cilium as the CNI
- [x] Add LoadBalancing
- [ ] Set up network-policies and document it
- [x] Add Sealed secrets
- [ ] Add an ingress controller
- [ ] Set up cert-manager
- [ ] Configure a service mesh for the cluster
- [ ] Make the services all mTLS
- [ ] Add ArgoCd
- [ ] Add first application

## Table of contents

- [Kubernetes Cluster Setup](#kubernetes-cluster-setup)
- [Cilium with LoadBalancing (CNI)](#cilium-with-loadbalancing-cni)
  - [LoadBalancing](#loadbalancing)
- [Secrets using Sealed Secrets](#secrets-using-sealed-secrets)
- [References](#references)

## Kubernetes Cluster Setup

When going through the guide bellow, you should:

1. Skip the last step.
2. Run this `sudo kubeadm init --control-plane-endpoint=k8s-master` when you are initializing the cluster.

Follow [this guide](https://www.linuxtechi.com/install-kubernetes-cluster-on-debian/).

## Cilium with LoadBalancing (CNI)

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

### LoadBalancing

With Cilium version `>=14`, IP-assignment and announcement is enabled easily by adding an ip-pool to the cluster and setting the `l2announcement.enabled=true`.

LoadBalancing is enabled in the `values.yaml`-file.

You can request spesific ips (like `192.168.0.200`) in the pool by annotation `LoadBalancer`s with `"io.cilium/lb-ipam-ips": "192.168.0.200"`.

## Secrets using Sealed Secrets

```bash
kubectl kustomize --enable-helm infrastructure/sealed-secrets | kubectl apply -f -
```

Now you can use Sealed secrets. [How to use them](./infrastructure/sealed-secrets/howto.md).

Might be an idea to make a backup of the private key (keep this safe):

```bash
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > master.yaml
```

## References

- [Link to cilium install guide](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)
