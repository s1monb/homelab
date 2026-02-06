#!/usr/bin/env bash

# Install cilium
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install cilium cilium/cilium --namespace kube-system --create-namespace --values cilium/values.yaml

# Install argo-cd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argo-cd argo/argo-cd --namespace argocd --create-namespace --values argocd/values.yaml

kubectl apply -f argocd/apps-of-apps.yaml