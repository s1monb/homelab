#!/usr/bin/env bash

# Install cilium
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --namespace kube-system --create-namespace --values cilium/values.yaml

echo "Now we have a working kubernetes api, and we can install the gitops-tool we want to use."