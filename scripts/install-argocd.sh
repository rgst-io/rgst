#!/usr/bin/env bash
# Installs ArgoCD on a Kubernetes cluster. This is replaced
# by the ArgoCD application that is created later.
set -eo pipefail

cluster_name="$1"
cluster_domain="$2"
if [[ -z "$cluster_name" || -z "$cluster_domain" ]]; then
  echo "Usage: $0 <cluster_name> <cluster_domain>"
  exit 1
fi

tmpFile=$(mktemp)
trap 'rm -f $tmpFile' EXIT

jsonnet -V "cluster_name=$cluster_name" -V "config_cluster_domain=$cluster_domain" \
  ./manifests/apps/default/argocd.jsonnet | yq -r .spec.source.helm.values >"$tmpFile"
helm template -f "$tmpFile" -n argocd argocd argocd/argo-cd

# argocd repo add https://github.com/rgst-io/rgst --github-app-id 245660 --github-app-installation-id 30025489 --github-app-private-key-path argocd-rgst**.pem --core
