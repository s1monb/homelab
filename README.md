# homelab

## Setup

### Setup the nodes

Follow [this guide](https://www.linuxtechi.com/install-kubernetes-cluster-on-debian/). Skip the last step.

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

```bash

```

## References

- Link to cilium (https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)
